import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// CarPlay-initiated refresh cycle over the offline fixture graph.
@MainActor
struct CarPlayRefreshCoordinatorTests {
    private func makeApp(
        network: FixtureNetwork,
        hasCachedSnapshot: Bool = true,
        locationAuthorization: CLAuthorizationStatus = .notDetermined,
        clock: TestClock? = nil
    ) -> AppContainer {
        AppContainer.fixture(
            region: .kyivCity,
            network: network,
            hasCachedSnapshot: hasCachedSnapshot,
            defaultsSuite: "RegionalCheckTests.carplay-refresh.\(UUID().uuidString)",
            locationAuthorization: locationAuthorization,
            clock: clock.map { clock in { clock.now } }
        )
    }

    private func makeCoordinator(
        _ app: AppContainer,
        backoffSleep: @escaping (Duration) async throws -> Void = { _ in },
        locationPollSleep: @escaping (Duration) async throws -> Void = { _ in }
    ) -> CarPlayRefreshCoordinator {
        CarPlayRefreshCoordinator(
            status: app.status,
            location: app.location,
            regions: app.regions,
            now: { AppContainer.fixtureNow },
            backoffSleep: backoffSleep,
            locationPollSleep: locationPollSleep
        )
    }

    @Test("REQ-PROVIDER-002 phone, CarPlay and widget requests equal exercised triggers", .timeLimit(.minutes(1)))
    func sharedFixtureCountsRequestsAcrossSurfaces() async {
        let network = FixtureNetwork()
        let suite = "RegionalCheckTests.provider-count.\(UUID().uuidString)"
        let app = AppContainer.fixture(network: network, defaultsSuite: suite)
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let coordinator = makeCoordinator(app)

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
            for _ in 0 ..< 10 {
                _ = WidgetTimelineBuilder.timeline(store: store, now: AppContainer.fixtureNow)
                _ = app.homeViewModel.secondaryRegionStatus
                coordinator.synchronizeWithStatus()
            }
            #expect(network.alertRequestCount == 2)
        }
        app.mapViewModel.appear()
        while app.mapViewModel.isLoading {
            await Task.yield()
        }
        #expect(network.mapRequestCount == 1)
        app.carPlayMapImage.appear()
        while app.carPlayMapImage.isLoading {
            await Task.yield()
        }
        #expect(network.mapRequestCount == 2)

        app.carPlayMapImage.setVariant(.night)
        while app.carPlayMapImage.isLoading {
            await Task.yield()
        }
        #expect(network.mapRequestCount == 3)
        app.mapViewModel.refresh()
        while app.mapViewModel.isLoading {
            await Task.yield()
        }
        #expect(network.mapRequestCount == 4)

        for _ in 0 ..< 10 {
            app.mapViewModel.appear()
            app.carPlayMapImage.appear()
            app.carPlayMapImage.setVariant(.night)
            _ = app.mapViewModel.fullscreenCaption
            _ = app.carPlayMapImage.accessibilityLabel
        }
        #expect(!app.mapViewModel.isLoading)
        #expect(!app.carPlayMapImage.isLoading)
        #expect(network.alertRequestCount == 2)
        #expect(network.mapRequestCount == 4)
    }

    @Test
    func refreshShowsLoadingWithCachedSnapshotImmediately() {
        let app = makeApp(network: FixtureNetwork())
        let coordinator = makeCoordinator(app)

        let task = coordinator.refresh(reason: "test")
        task.cancel()

        #expect(coordinator.loadState == .loading(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status)))
        #expect(coordinator.loadState.snapshot != nil)
    }

    @Test
    func successfulRefreshEndsLoaded() async {
        let network = FixtureNetwork()
        let app = makeApp(network: network, hasCachedSnapshot: false)
        let coordinator = makeCoordinator(app)

        await coordinator.refresh(reason: "test").value

        guard case let .loaded(snapshot) = coordinator.loadState else {
            Issue.record("Expected loaded, got \(coordinator.loadState)")
            return
        }
        #expect(snapshot.checkedAt == AppContainer.fixtureNow)
        #expect(network.alertRequestCount == 1)
    }

    @Test("REQ-REFRESH-004 the CarPlay cycle makes three attempts with 2s then 4s backoff")
    func failingNetworkRetriesThreeTimesWithBackoffAndKeepsCache() async throws {
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        var delays: [Duration] = []
        let coordinator = makeCoordinator(app, backoffSleep: { delays.append($0) })

        await coordinator.refresh(reason: "test").value

        #expect(network.alertRequestCount == CarPlayRefreshCoordinator.maxAttempts)
        #expect(delays == [.seconds(2), .seconds(4)])
        #expect(coordinator.loadState == .failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status)))
        let cached = try #require(coordinator.loadState.snapshot)
        #expect(coordinator.freshness().isFresh(cached))
    }

    @Test("REQ-REFRESH-004 a later attempt in the cycle recovers from a transient failure")
    func retrySucceedsAfterTransientFailure() async {
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        let coordinator = makeCoordinator(app, backoffSleep: { _ in network.failsRequests = false })

        await coordinator.refresh(reason: "test").value

        #expect(network.alertRequestCount == 2)
        #expect(!app.status.hasRefreshFailed)
        if case .loaded = coordinator.loadState {} else {
            Issue.record("Expected loaded, got \(coordinator.loadState)")
        }
    }

    @Test("REQ-REFRESH-004 a cancelled cycle never strands the load state in loading")
    func cancelledCycleLeavesLoading() async {
        final class Box {
            var coordinator: CarPlayRefreshCoordinator?
        }
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        let box = Box()
        // `cancel()` arrives mid-cycle, during the first backoff — the CarPlay scene disconnecting
        // while a refresh is still running. The Status template's button reads `isLoading`, so a
        // state left in `.loading` is a button stuck on "Checking…" with nothing left to clear it.
        let coordinator = makeCoordinator(app, backoffSleep: { _ in box.coordinator?.cancel() })
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
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        let restart = Restart()
        let coordinator = makeCoordinator(app, backoffSleep: { _ in
            // A manual Refresh arrives during the first backoff and the network recovers.
            guard restart.manual == nil else { return }
            network.failsRequests = false
            restart.manual = restart.coordinator?.refresh(reason: "manual")
        })
        restart.coordinator = coordinator

        await coordinator.refresh(reason: "connect").value
        let manual = try #require(restart.manual)
        await manual.value

        // The superseded cycle's failure must not overwrite the newer result.
        if case .loaded = coordinator.loadState {} else {
            Issue.record("Expected loaded, got \(coordinator.loadState)")
        }
    }

    @Test
    func externalFailureAfterLoadedKeepsCachedSnapshot() async {
        let network = FixtureNetwork()
        let clock = TestClock(AppContainer.fixtureNow)
        let app = makeApp(network: network, clock: clock)
        let coordinator = makeCoordinator(app)
        await coordinator.refresh(reason: "test").value

        network.failsRequests = true
        clock.advancePastFetchFloor()
        await app.status.refresh(isScheduled: true)
        coordinator.synchronizeWithStatus()

        #expect(coordinator.loadState == .failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status)))
    }

    // MARK: - Location hermeticity (RD-8b follow-up: a real `LocationManager()` reads whatever

    // location permission the current simulator happens to have granted this bundle ID, which
    // made `retrySucceedsAfterTransientFailure` and `failingNetworkRetriesThreeTimesWithBackoffAndKeepsCache`
    // flaky on a simulator where the app had once been granted access for real. The fixture's
    // location is a fake (`FixtureLocationManager`) defaulting to `.notDetermined`, and the
    // coordinator's location-wait sleep is a separate closure from its retry-backoff sleep, so
    // the two can never share one recorded array again.

    @Test
    func hermeticDefaultNeverEngagesLocationWait() async {
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        var locationDelays: [Duration] = []
        let coordinator = makeCoordinator(app, locationPollSleep: { locationDelays.append($0) })

        await coordinator.refresh(reason: "test").value

        #expect(locationDelays.isEmpty)
    }

    @Test
    func forcedAuthorizationWithoutAFixEngagesLocationWaitUpToTheTimeout() async {
        let network = FixtureNetwork()
        let app = makeApp(network: network, locationAuthorization: .authorizedWhenInUse)
        var locationDelays: [Duration] = []
        let coordinator = makeCoordinator(app, locationPollSleep: { locationDelays.append($0) })

        await coordinator.refresh(reason: "test").value

        // 5 s timeout / 250 ms poll interval, on its own array — never mixed into backoff delays.
        #expect(locationDelays == Array(repeating: .milliseconds(250), count: 20))
    }

    @Test
    func forcedAuthorizationWithAFixSkipsTheRemainingWait() async throws {
        let network = FixtureNetwork()
        let fix = LocationFix(
            coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
            horizontalAccuracy: 100,
            timestamp: .now
        )
        let app = makeApp(network: network, locationAuthorization: .authorizedWhenInUse)
        let fixtureLocation = try #require(app.location as? FixtureLocationManager)
        var locationDelays: [Duration] = []
        let coordinator = makeCoordinator(app, locationPollSleep: {
            locationDelays.append($0)
            fixtureLocation.lastFix = fix
        })

        await coordinator.refresh(reason: "test").value

        #expect(locationDelays == [.milliseconds(250)])
    }
}
