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
    /// paint it, so a Pro gate on either fails one of the two runs.
    @Test("REQ-SURF-002 the alarm and the map reach a driver without Pro as with it", arguments: [false, true])
    func safetySignalAndMapNeedNoPro(isPro: Bool) async {
        let network = FixtureNetwork(alarmRegions: [.kyivCity])
        let app = makeApp(network: network, isPro: isPro)
        #expect(app.subscription.isPro == isPro)

        await app.homeViewModel.refresh()
        #expect(app.status.state.phase == .alarm)
        #expect(AlertMapFill.fill(for: .region(.kyivCity), snapshot: app.status.lastSnapshot) == .alarm)
    }

    /// The map is drawn from the status's own snapshot, so through launch, polls, pulls, a pull
    /// held by the fetch floor, a failed pull and a background poll the app sends no map request,
    /// and every new snapshot's alarm set is the one the map paints.
    @Test("MAP-native AC-3 AC-10 the map follows the status and sends no request")
    func mapFollowsTheStatusWithoutARequest() async {
        let network = FixtureNetwork(alarmRegions: [.kyivCity])
        let clock = TestClock(AppContainer.fixtureNow)
        let app = makeApp(network: network, clock: clock)
        await app.homeViewModel.refresh()
        #expect(AlertMapFill.fill(for: .region(.kyivOblast), snapshot: app.status.lastSnapshot) == .quiet)

        network.alarmRegions = [.kyivCity, .kyivOblast]
        clock.advancePastFetchFloor()
        await app.status.refresh()
        #expect(AlertMapFill.fill(for: .region(.kyivOblast), snapshot: app.status.lastSnapshot) == .alarm)

        network.alarmRegions = [.kyivCity]
        clock.advancePastFetchFloor()
        await app.pullToRefresh()
        #expect(AlertMapFill.fill(for: .region(.kyivOblast), snapshot: app.status.lastSnapshot) == .quiet)

        await app.pullToRefresh()
        network.failsRequests = true
        clock.advancePastFetchFloor()
        await app.pullToRefresh()
        network.failsRequests = false
        app.liveActivity.endPhoneForegroundSession()
        clock.advancePastFetchFloor()
        await app.status.refresh()

        #expect(network.alertRequestCount > 0)
        #expect(network.mapRequestCount == 0)
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
