import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// CarPlay-initiated refresh cycle over the offline fixture graph.
@MainActor
struct CarPlayRefreshCoordinatorTests {
    private func makeApp(network: FixtureNetwork, hasCachedSnapshot: Bool = true) -> AppContainer {
        AppContainer.fixture(
            region: .kyivCity,
            network: network,
            hasCachedSnapshot: hasCachedSnapshot,
            defaultsSuite: "RegionalCheckTests.carplay-refresh.\(UUID().uuidString)"
        )
    }

    private func makeCoordinator(
        _ app: AppContainer,
        sleep: @escaping (Duration) async throws -> Void = { _ in }
    ) -> CarPlayRefreshCoordinator {
        CarPlayRefreshCoordinator(
            status: app.status,
            location: app.location,
            regions: app.regions,
            now: { AppContainer.fixtureNow },
            sleep: sleep
        )
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

    @Test
    func failingNetworkRetriesThreeTimesWithBackoffAndKeepsCache() async throws {
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        var delays: [Duration] = []
        let coordinator = makeCoordinator(app) { delays.append($0) }

        await coordinator.refresh(reason: "test").value

        #expect(network.alertRequestCount == CarPlayRefreshCoordinator.maxAttempts)
        #expect(delays == [.seconds(2), .seconds(4)])
        #expect(coordinator.loadState == .failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status)))
        let cached = try #require(coordinator.loadState.snapshot)
        #expect(coordinator.freshness().isFresh(cached))
    }

    @Test
    func retrySucceedsAfterTransientFailure() async {
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        let coordinator = makeCoordinator(app) { _ in network.failsRequests = false }

        await coordinator.refresh(reason: "test").value

        #expect(network.alertRequestCount == 2)
        #expect(!app.status.hasRefreshFailed)
        if case .loaded = coordinator.loadState {} else {
            Issue.record("Expected loaded, got \(coordinator.loadState)")
        }
    }

    @Test
    func newRefreshSupersedesRunningCycle() async throws {
        final class Restart {
            var coordinator: CarPlayRefreshCoordinator?
            var manual: Task<Void, Never>?
        }
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        let restart = Restart()
        let coordinator = makeCoordinator(app) { _ in
            // A manual Refresh arrives during the first backoff and the network recovers.
            guard restart.manual == nil else { return }
            network.failsRequests = false
            restart.manual = restart.coordinator?.refresh(reason: "manual")
        }
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
        let app = makeApp(network: network)
        let coordinator = makeCoordinator(app)
        await coordinator.refresh(reason: "test").value

        network.failsRequests = true
        await app.status.refresh(isScheduled: true)
        coordinator.synchronizeWithStatus()

        #expect(coordinator.loadState == .failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status)))
    }
}
