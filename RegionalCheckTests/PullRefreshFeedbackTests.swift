import Foundation
@testable import RegionalCheck
import Testing

/// Run through the real `StatusController` rather than a mock: whether a pull sent a request, was
/// held by the fetch floor, or failed is decided there, and the feedback must follow it.
@MainActor
struct PullRefreshFeedbackTests {
    private func makeContainer(network: FixtureNetwork = FixtureNetwork()) -> AppContainer {
        AppContainer.fixture(network: network, defaultsSuite: "RegionalCheckTests.pull-feedback.\(UUID().uuidString)")
    }

    @Test("REQ-REFRESH-011 a pull that fetches answers with the success haptic")
    func pullThatFetchesCompletes() async {
        let network = FixtureNetwork()
        let app = makeContainer(network: network)

        await app.homeViewModel.pullToRefresh()

        #expect(network.alertRequestCount == 1)
        #expect(app.homeViewModel.pullRefreshFeedback?.outcome == .completed)
    }

    @Test("REQ-REFRESH-011 a pull held by the fetch floor still answers with the success haptic")
    func pullHeldByTheFetchFloorCompletes() async {
        let network = FixtureNetwork()
        let app = makeContainer(network: network)

        await app.homeViewModel.pullToRefresh()
        await app.homeViewModel.pullToRefresh()

        // The fixture clock does not move, so the second pull falls inside the floor.
        #expect(network.alertRequestCount == 1)
        #expect(app.homeViewModel.pullRefreshFeedback?.outcome == .completed)
        #expect(app.homeViewModel.pullRefreshFeedback?.sequence == 2)
    }

    @Test("REQ-REFRESH-011 a pull whose request fails answers with the error haptic")
    func pullWhoseRequestFailsReportsFailure() async {
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeContainer(network: network)

        await app.homeViewModel.pullToRefresh()

        #expect(app.homeViewModel.pullRefreshFeedback?.outcome == .failed)
    }

    @Test("REQ-REFRESH-011 a refresh the driver did not start plays no haptic")
    func refreshNotStartedByThePullPlaysNothing() async {
        let app = makeContainer()

        await app.homeViewModel.refresh()

        #expect(app.homeViewModel.pullRefreshFeedback == nil)
    }
}
