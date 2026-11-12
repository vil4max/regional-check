import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The safety signal and the alert map through the real composition root, as in
/// `AppScenarioTests`, with only the network, clock and storage replaced.
@MainActor
@Suite(.removesDefaultsSuites)
struct AppScenarioMapTests {
    /// The signal and the map with and without Pro: both arguments must reach the same alarm and
    /// load the same map, so a Pro gate on either fails one of the two runs.
    @Test("REQ-SURF-002 the alarm and the map reach a driver without Pro as with it", arguments: [false, true])
    func safetySignalAndMapNeedNoPro(isPro: Bool) async throws {
        let network = FixtureNetwork(alarmRegions: [.kyivCity])
        let app = makeApp(network: network, isPro: isPro)
        #expect(app.subscription.isPro == isPro)

        await app.homeViewModel.refresh()
        #expect(app.status.state.phase == .alarm)

        let map = app.mapViewModel
        map.appear()
        try #require(await eventually { !map.isLoading })
        #expect(map.loadFailed == false)
        #expect(map.imageData != nil)
    }

    @Test("UI-simplify AC-4 the Status pull fetches the status, then brings back a failed map, once")
    func pullBringsBackAFailedMap() async throws {
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        let map = app.mapViewModel

        map.appear()
        try #require(await eventually { !map.isLoading })
        #expect(map.loadFailed)
        let alertsBefore = network.alertRequestCount
        let mapsBefore = network.mapRequestCount

        network.failsRequests = false
        await app.pullToRefresh()
        try #require(await eventually { !map.isLoading })

        #expect(network.alertRequestCount == alertsBefore + 1)
        #expect(network.mapRequestCount == mapsBefore + 1)
        #expect(map.loadFailed == false)
        #expect(map.imageData != nil)

        await app.pullToRefresh()
        try #require(await eventually { !map.isLoading })
        #expect(network.mapRequestCount == mapsBefore + 1)
    }

    /// MAP-sync through the real `StatusController`: its observable snapshot drives the map, a
    /// pull that fetched reloads it, and a phone in the background stays silent.
    @Test("REQ-PROVIDER-002 MAP-sync AC-1 AC-2 the map follows the status through the real composition root")
    func mapFollowsTheStatus() async throws {
        let network = FixtureNetwork(alarmRegions: [.kyivCity])
        let clock = TestClock(AppContainer.fixtureNow)
        let app = makeApp(network: network, clock: clock)
        let map = app.mapViewModel
        await app.homeViewModel.refresh()
        map.appear()
        try #require(await eventually { !map.isLoading && map.visibleImageData != nil })
        let maps = network.mapRequestCount

        // A status refresh outside the pull that changes the set: the observer alone reloads.
        network.alarmRegions = [.kyivCity, .kyivOblast]
        clock.advancePastFetchFloor()
        await app.status.refresh()
        try #require(await eventually { network.mapRequestCount == maps + 1 && !map.isLoading })
        #expect(map.visibleImageData != nil)

        // A pull that changes the set: the observer and the pull together send one map request.
        network.alarmRegions = [.kyivCity]
        clock.advancePastFetchFloor()
        await app.pullToRefresh()
        try #require(await eventually { !map.isLoading })
        #expect(network.mapRequestCount == maps + 2)

        // A pull with the same set still reloads behind its own status request (AC-2) ...
        clock.advancePastFetchFloor()
        await app.pullToRefresh()
        try #require(await eventually { !map.isLoading })
        #expect(network.mapRequestCount == maps + 3)

        // ... and one held by the fetch floor sends no map request.
        let alerts = network.alertRequestCount
        await app.pullToRefresh()
        try #require(await eventually { !map.isLoading })
        #expect(network.alertRequestCount == alerts)
        #expect(network.mapRequestCount == maps + 3)

        // A pull whose status request fails sends no map request either: no new snapshot arrived.
        network.failsRequests = true
        clock.advancePastFetchFloor()
        await app.pullToRefresh()
        try #require(await eventually { !map.isLoading })
        #expect(network.alertRequestCount > alerts)
        #expect(network.mapRequestCount == maps + 3)
        network.failsRequests = false

        // In the background (a CarPlay poll) a changed set sends nothing.
        map.endForegroundSession()
        network.alarmRegions = [.kyivCity, .kharkiv]
        clock.advancePastFetchFloor()
        await app.status.refresh()
        let reloaded = await eventually(timeout: .milliseconds(300)) { network.mapRequestCount > maps + 3 }
        #expect(!reloaded)
    }

    private func makeApp(network: FixtureNetwork, isPro: Bool = false, clock: TestClock? = nil) -> AppContainer {
        AppContainer.fixture(
            region: .kyivCity,
            network: network,
            isPro: isPro,
            defaultsSuite: TestDefaults.fixtureSuite("scenario-map"),
            clock: clock.map { clock in { clock.now } }
        )
    }
}
