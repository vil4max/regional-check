import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// CarPlay-initiated refresh cycle over a scripted status store; the request count across
/// surfaces runs over the offline fixture graph.
@MainActor
@Suite(.removesDefaultsSuites)
struct CarPlayRefreshCoordinatorTests {
    private func makeStatus(hasCachedSnapshot: Bool = true) -> FakeCarPlayStatus {
        let snapshot = FixtureNetwork.snapshot(alarmRegions: [.kharkiv])
        let status = FakeCarPlayStatus(region: .kyivCity, snapshot: hasCachedSnapshot ? snapshot : nil)
        status.refreshedSnapshot = snapshot
        return status
    }

    private func makeCoordinator(
        _ status: any CarPlayStatusRefreshing,
        location: any CarPlayLocationSource = FixtureLocationManager(),
        backoffSleep: @escaping (Duration) async throws -> Void = { _ in },
        locationPollSleep: @escaping (Duration) async throws -> Void = { _ in }
    ) -> CarPlayRefreshCoordinator {
        CarPlayRefreshCoordinator(
            status: status,
            location: location,
            now: { AppContainer.fixtureNow },
            backoffSleep: backoffSleep,
            locationPollSleep: locationPollSleep
        )
    }

    @Test("REQ-PROVIDER-002 phone, CarPlay and widget requests equal exercised triggers", .timeLimit(.minutes(1)))
    func sharedFixtureCountsRequestsAcrossSurfaces() async throws {
        let network = FixtureNetwork()
        let app = AppContainer.fixture(network: network, defaultsSuite: TestDefaults.fixtureSuite("provider-count"))
        let coordinator = makeCoordinator(app.status, location: app.location)

        // One logical session, no elapsed time. The phone's fetch is the session's first and goes
        // out immediately; the CarPlay refresh arrives inside the fetch floor and is served from
        // the held snapshot (REQ-REFRESH-010) — two surfaces, one request.
        #expect(network.alertRequestCount == 0)
        await app.homeViewModel.refresh()
        #expect(network.alertRequestCount == 1)
        await coordinator.refresh(reason: "manual").value
        #expect(network.alertRequestCount == 1)
        if let held = CarPlayRefreshCoordinator.cachedSnapshot(from: app.status) {
            #expect(coordinator.loadState == .loaded(held))
        } else {
            Issue.record("Expected the held snapshot to be served to CarPlay")
        }

        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            await WidgetTimelineRefresh.refresh(store: store, provider: app.provider)
            #expect(network.alertRequestCount == 2)
            for _ in 0..<10 {
                _ = WidgetTimelineBuilder.timeline(store: store, now: AppContainer.fixtureNow)
                coordinator.synchronizeWithStatus()
            }
            #expect(network.alertRequestCount == 2)
        }
        try await exerciseMapTriggers(app.mapViewModel, network: network)

        // CarPlay has no map (REQ-SURF-006): nothing it renders may add a map request.
        for _ in 0..<10 {
            app.mapViewModel.appear()
            app.mapViewModel.setVariant(.night)
            _ = app.mapViewModel.fullscreenCaption
            coordinator.synchronizeWithStatus()
        }
        #expect(!app.mapViewModel.isLoading)
        #expect(network.alertRequestCount == 2)
        #expect(network.mapRequestCount == 3)
    }

    @Test("A cycle shows loading with the cached snapshot at once")
    func refreshShowsLoadingWithCachedSnapshotImmediately() {
        let status = makeStatus()
        let coordinator = makeCoordinator(status)

        let task = coordinator.refresh(reason: "test")
        task.cancel()

        #expect(coordinator.loadState == .loading(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status)))
        #expect(coordinator.loadState.snapshot != nil)
    }

    @Test("A successful first attempt ends the cycle loaded")
    func successfulRefreshEndsLoaded() async {
        let status = makeStatus(hasCachedSnapshot: false)
        let coordinator = makeCoordinator(status)

        await coordinator.refresh(reason: "test").value

        guard case let .loaded(snapshot) = coordinator.loadState else {
            Issue.record("Expected loaded, got \(coordinator.loadState)")
            return
        }
        #expect(snapshot.checkedAt == AppContainer.fixtureNow)
        #expect(status.refreshCount == 1)
    }

    @Test("REQ-REFRESH-004 the CarPlay cycle makes three attempts with 2s then 4s backoff")
    func failingNetworkRetriesThreeTimesWithBackoffAndKeepsCache() async throws {
        let status = makeStatus()
        status.failsRefresh = true
        var delays: [Duration] = []
        let coordinator = makeCoordinator(status, backoffSleep: { delays.append($0) })

        await coordinator.refresh(reason: "test").value

        #expect(status.refreshCount == CarPlayRefreshCoordinator.maxAttempts)
        #expect(delays == [.seconds(2), .seconds(4)])
        #expect(coordinator.loadState == .failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status)))
        let cached = try #require(coordinator.loadState.snapshot)
        #expect(coordinator.freshness().isFresh(cached))
    }

    @Test("REQ-REFRESH-004 a later attempt in the cycle recovers from a transient failure")
    func retrySucceedsAfterTransientFailure() async {
        let status = makeStatus()
        status.failsRefresh = true
        let coordinator = makeCoordinator(status, backoffSleep: { _ in status.failsRefresh = false })

        await coordinator.refresh(reason: "test").value

        #expect(status.refreshCount == 2)
        #expect(!status.hasRefreshFailed)
        if case .loaded = coordinator.loadState {
        } else {
            Issue.record("Expected loaded, got \(coordinator.loadState)")
        }
    }

    @Test("REQ-REFRESH-004 a rate-limited failure ends the cycle without another attempt")
    func rateLimitedFailureStopsRetrying() async {
        let status = makeStatus()
        status.failsRefresh = true
        status.isRateLimited = true
        var delays: [Duration] = []
        let coordinator = makeCoordinator(status, backoffSleep: { delays.append($0) })

        await coordinator.refresh(reason: "test").value

        #expect(status.refreshCount == 1)
        #expect(delays.isEmpty)
        #expect(coordinator.loadState == .failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status)))
    }
}

extension CarPlayRefreshCoordinatorTests {
    /// The phone map's three enumerated triggers (first appearance, variant change, Refresh), one
    /// request each (REQ-PROVIDER-002).
    private func exerciseMapTriggers(_ map: MapViewModel, network: FixtureNetwork) async throws {
        map.appear()
        try #require(await eventually { !map.isLoading })
        #expect(network.mapRequestCount == 1)

        map.setVariant(.night)
        try #require(await eventually { !map.isLoading })
        #expect(network.mapRequestCount == 2)
        map.refresh()
        try #require(await eventually { !map.isLoading })
        #expect(network.mapRequestCount == 3)
    }

    @Test("REQ-REFRESH-004 a cancelled cycle never strands the load state in loading")
    func cancelledCycleLeavesLoading() async {
        final class Box {
            var coordinator: CarPlayRefreshCoordinator?
        }
        let status = makeStatus()
        status.failsRefresh = true
        let box = Box()
        // `cancel()` arrives mid-cycle, during the first backoff — the CarPlay scene disconnecting
        // while a refresh is still running. The Status template's button reads `isLoading`, so a
        // state left in `.loading` is a button stuck on "Checking…" with nothing left to clear it.
        let coordinator = makeCoordinator(status, backoffSleep: { _ in box.coordinator?.cancel() })
        box.coordinator = coordinator

        await coordinator.refresh(reason: "connect").value

        #expect(!coordinator.loadState.isLoading)
    }

    @Test("REQ-REFRESH-004 a new cycle supersedes the running one")
    func newRefreshSupersedesRunningCycle() async throws {
        final class Restart {
            var coordinator: CarPlayRefreshCoordinator?
            var manual: Task<Void, Never>?
        }
        let status = makeStatus()
        status.failsRefresh = true
        let restart = Restart()
        let coordinator = makeCoordinator(
            status,
            backoffSleep: { _ in
                // A manual Refresh arrives during the first backoff and the network recovers.
                guard restart.manual == nil else { return }
                status.failsRefresh = false
                restart.manual = restart.coordinator?.refresh(reason: "manual")
            })
        restart.coordinator = coordinator

        await coordinator.refresh(reason: "connect").value
        let manual = try #require(restart.manual)
        await manual.value

        // The superseded cycle's failure must not overwrite the newer result.
        if case .loaded = coordinator.loadState {
        } else {
            Issue.record("Expected loaded, got \(coordinator.loadState)")
        }
    }

    @Test("REQ-REFRESH-007 a failure outside the cycle keeps the cached snapshot")
    func externalFailureAfterLoadedKeepsCachedSnapshot() async {
        let status = makeStatus()
        let coordinator = makeCoordinator(status)
        await coordinator.refresh(reason: "test").value

        status.hasRefreshFailed = true
        coordinator.synchronizeWithStatus()

        #expect(coordinator.loadState == .failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status)))
    }

    // MARK: - Location wait
    // The location source is a fake defaulting to `.notDetermined`, never the permission this
    // simulator has granted the bundle ID, and the location-wait sleep is a separate closure from
    // the retry backoff, so the two recordings never mix.

    @Test
    func hermeticDefaultNeverEngagesLocationWait() async {
        let status = makeStatus()
        status.failsRefresh = true
        var locationDelays: [Duration] = []
        let coordinator = makeCoordinator(status, locationPollSleep: { locationDelays.append($0) })

        await coordinator.refresh(reason: "test").value

        #expect(locationDelays.isEmpty)
    }

    @Test
    func forcedAuthorizationWithoutAFixEngagesLocationWaitUpToTheTimeout() async {
        var locationDelays: [Duration] = []
        let coordinator = makeCoordinator(
            makeStatus(),
            location: FixtureLocationManager(authorizationStatus: .authorizedWhenInUse),
            locationPollSleep: { locationDelays.append($0) }
        )

        await coordinator.refresh(reason: "test").value

        // 5 s timeout / 250 ms poll interval, on its own array — never mixed into backoff delays.
        #expect(locationDelays == Array(repeating: .milliseconds(250), count: 20))
    }

    @Test
    func forcedAuthorizationWithAFixSkipsTheRemainingWait() async {
        let fix = LocationFix(
            coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
            horizontalAccuracy: 100,
            timestamp: .now
        )
        let location = FixtureLocationManager(authorizationStatus: .authorizedWhenInUse)
        var locationDelays: [Duration] = []
        let coordinator = makeCoordinator(
            makeStatus(),
            location: location,
            locationPollSleep: {
                locationDelays.append($0)
                location.lastFix = fix
            })

        await coordinator.refresh(reason: "test").value

        #expect(locationDelays == [.milliseconds(250)])
    }
}
