import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// User flows driven through the real composition root (`AppContainer.fixture`):
/// ViewModels, `StatusController`, persistence, and the map card talk to each other
/// exactly as in the app, with only the network, clock, and storage replaced.
@MainActor
struct AppScenarioTests {
    @Test
    func launchShowsCachedStatusBeforeAnyNetwork() {
        let network = FixtureNetwork(alarmRegions: [.kharkiv])
        let app = makeApp(region: .kyivCity, network: network)

        #expect(app.status.state.phase == .quiet)
        #expect(app.status.regionTitle == AlertRegion.kyivCity.title)
        #expect(app.status.state.checkedAt == AppContainer.fixtureNow)
        #expect(app.status.isDataStale == false)
        #expect(network.alertRequestCount == 0)
    }

    @Test
    func appearRefreshesAndHomeReflectsNewAlarm() async {
        let network = FixtureNetwork(alarmRegions: [])
        let app = makeApp(region: .kyivCity, network: network)

        app.mainTabViewModel.appear()
        network.alarmRegions = [.kyivCity]
        await app.homeViewModel.refresh()

        #expect(app.status.state.phase == .alarm)
        #expect(app.statusPersistence.loadSnapshot()?.status(for: .kyivCity) == .alarm)
        #expect(network.alertRequestCount >= 1)
        app.mainTabViewModel.disappear()
    }

    @Test
    func pinningRegionInRegionsTabSwitchesHomeStatus() async {
        let network = FixtureNetwork(alarmRegions: [.odesa])
        let app = makeApp(region: .kyivCity, network: network)
        await app.homeViewModel.refresh()
        #expect(app.status.state.phase == .quiet)

        app.regionsViewModel.pin(.odesa)
        app.mainTabViewModel.regionChanged(app.regions.selectedRegion)

        #expect(app.regionsViewModel.selectedRegion == .odesa)
        #expect(app.regionsViewModel.followsLocation == false)
        #expect(app.status.regionTitle == AlertRegion.odesa.title)
        #expect(app.status.state.phase == .alarm)
        #expect(app.regionsViewModel.alarmRegions.contains(.odesa))
    }

    @Test
    func offlineRefreshKeepsLastKnownStatusAndMarksItStale() async {
        let network = FixtureNetwork(alarmRegions: [.kyivCity])
        let app = makeApp(region: .kyivCity, network: network)
        await app.homeViewModel.refresh()
        #expect(app.status.state.phase == .alarm)

        network.failsRequests = true
        await app.homeViewModel.refresh()

        #expect(app.status.hasRefreshFailed)
        #expect(app.status.isDataStale)
        #expect(app.status.lastKnownState?.phase == .alarm)

        network.failsRequests = false
        await app.homeViewModel.refresh()
        #expect(app.status.isDataStale == false)
        #expect(app.status.state.phase == .alarm)
    }

    @Test
    func proUserSeesSourceAndPinnedSecondaryRegionOnHome() {
        let app = makeApp(region: .kyivCity, isPro: true)

        #expect(app.homeViewModel.isPro)
        #expect(app.homeViewModel.sourceLabel != nil)
        #expect(app.regionsViewModel.canPinSecondaryRegion)

        app.regionsViewModel.pinSecondaryRegion(.lviv)

        // RD-5 replaced `secondaryRegionTitle` (a pre-formatted string) with `secondaryRegion`
        // (the raw region), so the redesigned "Also watching" row can show its own live status.
        #expect(app.homeViewModel.secondaryRegion == .lviv)
    }

    @Test
    func freeUserCannotPinSecondaryRegion() {
        let app = makeApp(region: .kyivCity, isPro: false)

        app.regionsViewModel.pinSecondaryRegion(.lviv)

        #expect(app.homeViewModel.isPro == false)
        #expect(app.homeViewModel.sourceLabel == nil)
        #expect(app.homeViewModel.secondaryRegion == nil)
        #expect(app.secondaryRegionStore.loadSecondaryRegion() == nil)
    }

    @Test
    func mapCardOnHomeLoadsOnceRetriesAfterOutage() async {
        let network = FixtureNetwork()
        network.failsRequests = true
        let app = makeApp(network: network)
        let map = app.mapViewModel

        map.appear()
        await settle { !map.isLoading }
        #expect(map.loadFailed)
        #expect(map.imageData == nil)

        network.failsRequests = false
        map.refresh()
        await settle { !map.isLoading }

        #expect(map.loadFailed == false)
        #expect(map.imageData != nil)
        #expect(map.loadedAt == AppContainer.fixtureNow)
        #expect(map.accessibilityLabel.isEmpty == false)

        let requestsBeforeReappear = network.mapRequestCount
        map.disappear()
        map.appear()
        #expect(network.mapRequestCount == requestsBeforeReappear)
    }

    @Test
    func statusDetailsSummarizeTheSelectedRegion() async {
        let network = FixtureNetwork(alarmRegions: [.kharkiv, .sumy])
        let app = makeApp(region: .kharkiv, network: network)
        await app.homeViewModel.refresh()
        let details = app.statusDetailsViewModel

        details.activate()
        await settle {
            if case .result = details.presentationState {
                return true
            }
            return false
        }

        guard case let .result(rows) = details.presentationState else {
            Issue.record("Expected a summary, got \(details.presentationState)")
            return
        }
        #expect(rows.isEmpty == false)
    }

    // MARK: Helpers

    private func makeApp(
        region: AlertRegion = .kyivCity,
        network: FixtureNetwork = FixtureNetwork(),
        isPro: Bool = false
    ) -> AppContainer {
        AppContainer.fixture(
            region: region,
            network: network,
            isPro: isPro,
            defaultsSuite: "RegionalCheckTests.scenario.\(UUID().uuidString)"
        )
    }

    private func settle(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 {
            if condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}
