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

    private func makeApp(network: FixtureNetwork, isPro: Bool = false) -> AppContainer {
        AppContainer.fixture(
            region: .kyivCity,
            network: network,
            isPro: isPro,
            defaultsSuite: TestDefaults.fixtureSuite("scenario-map")
        )
    }
}
