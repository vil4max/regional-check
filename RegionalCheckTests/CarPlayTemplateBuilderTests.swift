import CarPlay
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// CarPlay templates built from the real status graph (`AppContainer.fixture`),
/// asserting what a driver sees without a connected CarPlay scene.
@MainActor
struct CarPlayTemplateBuilderTests {

    // MARK: - Status tab

    @Test("REQ-SURF-001 quiet title uses the full form and marker")
    func quietTitleUsesFullFormAndMarker() async {
        await TestLocale.english {
            let app = makeApp(region: .kyivCity, network: FixtureNetwork(alarmRegions: []))
            await app.status.refresh()

            let template = statusBuilder(app).rootTemplate(loadState: loaded(app), freshness: freshness(app))

            #expect(template.title == "🟢 No Alert")
            #expect(template.items.first?.title == app.status.regionTitle)
            #expect(template.items.first?.detail?.hasPrefix("Automatic · Updated") == true)
        }
    }

    @Test("REQ-SURF-001 alarm title uses the full form, not the short pill word")
    func alarmTitleUsesFullForm() async {
        await TestLocale.english {
            let app = makeApp(region: .kharkiv, network: FixtureNetwork(alarmRegions: [.kharkiv]))
            await app.status.refresh()

            let template = statusBuilder(app).rootTemplate(loadState: loaded(app), freshness: freshness(app))

            #expect(template.title == "🚨 Air Raid Alert")
            #expect(app.status.state.title == "Alert") // the short form stays unchanged elsewhere
        }
    }

    @Test("REQ-SURF-005 nearby row shows in the alarm phase too, not only quiet")
    func nearbyRowShowsDuringAlarm() async {
        await TestLocale.english {
            let app = makeApp(region: .kharkiv, network: FixtureNetwork(alarmRegions: [.kharkiv, .sumy]))
            await app.status.refresh()

            let template = statusBuilder(app).rootTemplate(loadState: loaded(app), freshness: freshness(app))

            #expect(template.items.contains { $0.title == "Nearby: Sumy Oblast" })
        }
    }

    @Test("REQ-SURF-005 nothing-nearby row shows when no neighbor is under alert")
    func nothingNearbyRowShowsWhenClear() async {
        await TestLocale.english {
            let app = makeApp(region: .kyivCity, network: FixtureNetwork(alarmRegions: []))
            await app.status.refresh()

            let template = statusBuilder(app).rootTemplate(loadState: loaded(app), freshness: freshness(app))

            #expect(template.items
                .contains { $0.title == "Nothing nearby" && $0.detail == "Neighboring regions are clear" })
        }
    }

    @Test("REQ-REFRESH-007 a failed request with a fresh cache keeps the cached status in the title")
    func failedRefreshWithFreshCacheKeepsCachedStatusInTitle() async {
        await TestLocale.english {
            let network = FixtureNetwork(alarmRegions: [.odesa])
            let app = makeApp(region: .odesa, network: network)
            await app.status.refresh()
            network.failsRequests = true
            await app.status.refresh()
            let state = CarPlayLoadState.failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status))

            let template = statusBuilder(app).rootTemplate(loadState: state, freshness: freshness(app))

            #expect(template.title == "🚨 Air Raid Alert")
        }
    }

    @Test("REQ-REFRESH-007 a stale cached status shows no current data and no marker")
    func staleCacheShowsNoCurrentDataWithoutMarker() async {
        await TestLocale.english {
            let network = FixtureNetwork(alarmRegions: [.odesa])
            let app = makeApp(region: .odesa, network: network)
            await app.status.refresh()
            network.failsRequests = true
            await app.status.refresh()
            let state = CarPlayLoadState.failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status))
            let later = freshness(app, advancedBy: 25 * 60)

            let template = statusBuilder(app).rootTemplate(loadState: state, freshness: later)

            #expect(template.title == "No Current Data")
            #expect(template.items.contains {
                $0.title == "Last known status: Alert" && $0.detail == "Data may be outdated — refresh"
            })
        }
    }

    @Test("Refresh is the only action; the Details button is removed (Details is a tab)")
    func refreshIsTheOnlyAction() {
        TestLocale.english {
            let app = makeApp(region: .kyivCity)
            let state = CarPlayLoadState.loading(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status))

            let template = statusBuilder(app).rootTemplate(loadState: state, freshness: freshness(app))

            #expect(template.actions.map(\.title) == ["Checking…"])
        }
    }

    // REQ-REGION-009 (location denied shows short CarPlay text instead of the nearby row) is
    // unchanged by this task and untestable here: `LocationManager.authorizationStatus` has no
    // test seam (it is set only from `CLLocationManagerDelegate` callbacks), same as before.

    // MARK: - Details tab

    @Test("REQ-SURF-006 Details rows are free regardless of Pro")
    func detailsRowsAreFreeForEveryone() async {
        await TestLocale.english {
            let free = makeApp(region: .kharkiv, network: FixtureNetwork(alarmRegions: [.kharkiv, .sumy]), isPro: false)
            await free.status.refresh()

            let sections = detailsBuilder(free).sections(loadState: loaded(free), freshness: freshness(free))

            #expect(sections.map(\.header) == ["YOUR REGION", "UKRAINE", "DATA"])
            #expect((sections[2].items.first as? CPListItem)?.detailText?.contains("Source:") == false)
        }
    }

    @Test("Pro shows the source row in the DATA section; free does not")
    func sourceRowIsProOnly() async {
        await TestLocale.english {
            let pro = makeApp(region: .kyivCity, isPro: true)
            await pro.status.refresh()

            let sections = detailsBuilder(pro).sections(loadState: loaded(pro), freshness: freshness(pro))

            #expect((sections[2].items.first as? CPListItem)?.detailText?.contains("Source:") == true)
        }
    }

    @Test("YOUR REGION reads the region and alert status; UKRAINE lists the affected regions")
    func yourRegionAndUkraineSectionsMatchTheSnapshot() async {
        await TestLocale.english {
            let network = FixtureNetwork(alarmRegions: [.kharkiv, .sumy])
            let app = makeApp(region: .kharkiv, network: network)
            await app.status.refresh()

            let sections = detailsBuilder(app).sections(loadState: loaded(app), freshness: freshness(app))

            #expect(sections[0].items.first?.text == "Kharkiv Oblast: air raid alert")
            #expect((sections[0].items.first as? CPListItem)?
                .detailText == "An air raid alert is currently active in the selected region.")
            #expect(sections[1].items.first?.text == "Alerts in 2 of 25 regions")
            // Declaration order in AlertRegion (sumy precedes kharkiv), not selection order.
            #expect((sections[1].items.first as? CPListItem)?.detailText == "Sumy Oblast, Kharkiv Oblast")
        }
    }

    // MARK: - Helpers

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

    private func loaded(_ app: AppContainer) -> CarPlayLoadState {
        CarPlayRefreshCoordinator.cachedSnapshot(from: app.status).map { .loaded($0) } ?? .failed(cached: nil)
    }

    private func freshness(_ app: AppContainer, advancedBy seconds: TimeInterval = 0) -> CarPlayFreshness {
        CarPlayFreshness(
            now: AppContainer.fixtureNow.addingTimeInterval(seconds),
            refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: app.status.refreshEnvironment())
        )
    }

    private func statusBuilder(_ app: AppContainer) -> CarPlayTemplateBuilder {
        CarPlayTemplateBuilder(
            status: app.status,
            regions: app.regions,
            location: app.location,
            onRefresh: {}
        )
    }

    private func detailsBuilder(_ app: AppContainer) -> CarPlayDetailsBuilder {
        CarPlayDetailsBuilder(status: app.status, regions: app.regions, subscription: app.subscription)
    }
}
