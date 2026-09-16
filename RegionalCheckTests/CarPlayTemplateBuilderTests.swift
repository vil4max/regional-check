import CarPlay
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// CarPlay templates built from the real status graph (`AppContainer.fixture`),
/// asserting what a driver sees without a connected CarPlay scene.
@MainActor
struct CarPlayTemplateBuilderTests {
    @Test
    func quietRegionListsNearbyAlertsAndBothActions() async {
        await TestLocale.english {
            let app = makeApp(region: .kyivCity, network: FixtureNetwork(alarmRegions: [.kyivOblast, .chernihiv]))
            await app.status.refresh()

            let template = builder(app).rootTemplate(state: app.status.state, regionTitle: app.status.regionTitle)

            #expect(template.title.hasPrefix("🟢"))
            #expect(template.items.first?.title == app.status.regionTitle)
            #expect(template.items.first?.detail == "Region selection: automatic")
            #expect(template.items.contains { $0.title == "Nearby regions under alert: 2" })
            #expect(template.actions.map(\.title) == ["Refresh", "Details"])
        }
    }

    @Test
    func alarmRegionUsesAlarmMarkerWithoutNearbyRow() async {
        await TestLocale.english {
            let app = makeApp(region: .kharkiv, network: FixtureNetwork(alarmRegions: [.kharkiv, .sumy]))
            await app.status.refresh()

            let template = builder(app).rootTemplate(state: app.status.state, regionTitle: app.status.regionTitle)

            #expect(template.title == "🚨 \(app.status.state.title)")
            #expect(template.items.contains { ($0.title ?? "").hasPrefix("Nearby regions") } == false)
        }
    }

    @Test
    func failedRefreshShowsNoCurrentDataWithLastKnownStatus() async {
        await TestLocale.english {
            let network = FixtureNetwork(alarmRegions: [.odesa])
            let app = makeApp(region: .odesa, network: network)
            await app.status.refresh()
            network.failsRequests = true
            await app.status.refresh()

            let template = builder(app).rootTemplate(state: app.status.state, regionTitle: app.status.regionTitle)

            #expect(template.title == "? No current data")
            #expect(template.items.contains { ($0.title ?? "").hasPrefix("Last known status:") })

            let details = builder(app).detailItems()
            #expect(details.contains { $0.title == "No current data" })
        }
    }

    @Test
    func detailItemsShowSourceOnlyForPro() async {
        await TestLocale.english {
            let pro = makeApp(region: .kyivCity, isPro: true)
            await pro.status.refresh()
            let free = makeApp(region: .kyivCity, isPro: false)
            await free.status.refresh()

            #expect(builder(pro).detailItems().contains { $0.title == "Source:" })
            #expect(builder(free).detailItems().contains { $0.title == "Source:" } == false)
            #expect(builder(free).detailItems().first?.title == free.status.regionTitle)
        }
    }

    private func makeApp(
        region: AlertRegion,
        network: FixtureNetwork = FixtureNetwork(),
        isPro: Bool = false
    ) -> AppContainer {
        AppContainer.fixture(
            region: region,
            network: network,
            isPro: isPro,
            defaultsSuite: "RegionalCheckTests.carplay.\(UUID().uuidString)"
        )
    }

    private func builder(_ app: AppContainer) -> CarPlayTemplateBuilder {
        CarPlayTemplateBuilder(
            status: app.status,
            statusDetails: app.statusDetailsViewModel,
            regions: app.regions,
            subscription: app.subscription,
            location: app.location,
            onRefresh: {},
            onShowDetails: { _ in }
        )
    }
}
