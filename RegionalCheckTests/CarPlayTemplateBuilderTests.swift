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

            let template = builder(app).rootTemplate(loadState: loaded(app), freshness: freshness(app))

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

            let template = builder(app).rootTemplate(loadState: loaded(app), freshness: freshness(app))

            #expect(template.title == "🚨 \(app.status.state.title)")
            #expect(template.items.contains { ($0.title ?? "").hasPrefix("Nearby regions") } == false)
        }
    }

    @Test
    func failedRefreshWithFreshCacheKeepsCachedStatusInTitle() async {
        await TestLocale.english {
            let network = FixtureNetwork(alarmRegions: [.odesa])
            let app = makeApp(region: .odesa, network: network)
            await app.status.refresh()
            network.failsRequests = true
            await app.status.refresh()
            let state = CarPlayLoadState.failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status))

            let template = builder(app).rootTemplate(loadState: state, freshness: freshness(app))

            #expect(template.title == "🚨 \(StatusState.alarm(lastCheckedAt: .now).title)")
            #expect(template.items.contains { ($0.title ?? "").hasPrefix("Last known status:") } == false)
        }
    }

    @Test
    func failedRefreshWithStaleCacheShowsNoCurrentDataWithAgedStatus() async {
        await TestLocale.english {
            let network = FixtureNetwork(alarmRegions: [.odesa])
            let app = makeApp(region: .odesa, network: network)
            await app.status.refresh()
            network.failsRequests = true
            await app.status.refresh()
            let state = CarPlayLoadState.failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status))
            let later = freshness(app, advancedBy: 25 * 60)

            let template = builder(app).rootTemplate(loadState: state, freshness: later)

            #expect(template.title == "? No current data")
            #expect(template.items.contains { $0.title?.hasPrefix("Last known status:") == true
                    && $0.title?.hasSuffix("· 25 min ago") == true
            })

            let details = builder(app).detailItems(loadState: state, freshness: later)
            #expect(details.contains { $0.title == "No current data" })
        }
    }

    @Test
    func loadingActionShowsCheckingFeedback() {
        TestLocale.english {
            let app = makeApp(region: .kyivCity)
            let state = CarPlayLoadState.loading(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: app.status))

            let template = builder(app).rootTemplate(loadState: state, freshness: freshness(app))

            #expect(template.actions.map(\.title) == ["Checking…", "Details"])
        }
    }

    @Test
    func detailItemsShowSourceOnlyForPro() async {
        await TestLocale.english {
            let pro = makeApp(region: .kyivCity, isPro: true)
            await pro.status.refresh()
            let free = makeApp(region: .kyivCity, isPro: false)
            await free.status.refresh()

            let proItems = builder(pro).detailItems(loadState: loaded(pro), freshness: freshness(pro))
            let freeItems = builder(free).detailItems(loadState: loaded(free), freshness: freshness(free))
            #expect(proItems.contains { $0.title == "Source:" })
            #expect(freeItems.contains { $0.title == "Source:" } == false)
            #expect(freeItems.first?.title == free.status.regionTitle)
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

    private func loaded(_ app: AppContainer) -> CarPlayLoadState {
        CarPlayRefreshCoordinator.cachedSnapshot(from: app.status).map { .loaded($0) } ?? .failed(cached: nil)
    }

    private func freshness(_ app: AppContainer, advancedBy seconds: TimeInterval = 0) -> CarPlayFreshness {
        CarPlayFreshness(
            now: AppContainer.fixtureNow.addingTimeInterval(seconds),
            refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: app.status.refreshEnvironment())
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
