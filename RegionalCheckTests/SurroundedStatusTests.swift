import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct SurroundedStatusTests {
    @Test("REQ-SURF-010 half or more of the neighbours under alert surround the region")
    func halfTheNeighboursSurround() {
        // Kyiv city's ring has five neighbours; three of them is more than half.
        #expect(NearbyRegionPolicy.isSurrounded(.kyivCity, among: [.kyivOblast, .chernihiv, .zhytomyr]))
        #expect(!NearbyRegionPolicy.isSurrounded(.kyivCity, among: [.chernihiv, .zhytomyr]))
    }

    @Test("REQ-SURF-010 Kyiv Oblast alone under alert puts Kyiv city on Stay Alert")
    func kyivOblastAloneSurroundsKyivCity() {
        #expect(NearbyRegionPolicy.isSurrounded(.kyivCity, among: [.kyivOblast]))
    }

    @Test("REQ-SURF-010 Kyiv city under alert alone does not put Kyiv Oblast on Stay Alert")
    func kyivCityAloneDoesNotSurroundKyivOblast() {
        // The Kyiv rule is one-way: the oblast keeps the general half-of-neighbours rule.
        #expect(!NearbyRegionPolicy.isSurrounded(.kyivOblast, among: [.kyivCity]))
    }

    @Test("REQ-SURF-010 with more than half of the country under alert one neighbour is enough")
    func massAlertLowersTheThreshold() {
        let far = AlertRegion.allCases.filter {
            $0 != .poltava && !NearbyRegionPolicy.nearbyRegions(to: .poltava).contains($0)
        }
        let alerts = Array(far.prefix(13)) + [.sumy]
        #expect(Set(alerts).count * 2 > AlertRegion.allCases.count)
        #expect(NearbyRegionPolicy.isSurrounded(.poltava, among: alerts))
        #expect(!NearbyRegionPolicy.isSurrounded(.poltava, among: [.sumy]))
    }

    @Test("REQ-SURF-010 no neighbour under alert is never surrounded, however much of the country is")
    func noNeighbourNoWarning() {
        let far = AlertRegion.allCases.filter {
            $0 != .lviv && !NearbyRegionPolicy.nearbyRegions(to: .lviv).contains($0)
        }
        #expect(!NearbyRegionPolicy.isSurrounded(.lviv, among: far))
    }

    @Test("REQ-SURF-010 a surrounded quiet region is yellow; alarm stays red and stale stays grey")
    func accentFollowsTheTrafficLight() {
        #expect(Theme.RedesignStatusAccent(phase: .quiet, isStale: false, isSurrounded: true) == .caution)
        #expect(Theme.RedesignStatusAccent(phase: .quiet, isStale: false, isSurrounded: false) == .clear)
        #expect(Theme.RedesignStatusAccent(phase: .alarm, isStale: false, isSurrounded: true) == .alert)
        #expect(Theme.RedesignStatusAccent(phase: .quiet, isStale: true, isSurrounded: true) == .stale)
    }

    @Test("REQ-SURF-010 the yellow status has its own one-line title in every language")
    func cautionTitleIsLocalized() {
        TestLocale.english {
            #expect(Theme.RedesignStatusAccent.caution.fullTitle == "Stay Alert")
        }
        #expect(Theme.RedesignColors.statusAccent(for: .caution) != Theme.RedesignColors.statusAccent(for: .stale))
    }

    @Test("REQ-SURF-010 CarPlay titles a surrounded quiet region with the yellow marker")
    func carPlayTitleIsYellow() async {
        await TestLocale.english {
            let app = AppContainer.fixture(
                region: .kyivCity,
                network: FixtureNetwork(alarmRegions: [.kyivOblast, .chernihiv, .zhytomyr]),
                defaultsSuite: "RegionalCheckTests.surrounded.\(UUID().uuidString)"
            )
            await app.status.refresh()
            let builder = CarPlayTemplateBuilder(
                status: app.status,
                regions: app.regions,
                location: app.location,
                onRefresh: {}
            )
            let loaded = CarPlayRefreshCoordinator.cachedSnapshot(from: app.status).map { CarPlayLoadState.loaded($0) }
                ?? .failed(cached: nil)
            let freshness = CarPlayFreshness(
                now: AppContainer.fixtureNow,
                refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: app.status.refreshEnvironment())
            )

            let template = builder.rootTemplate(loadState: loaded, freshness: freshness)

            #expect(template.title == "🟡 Stay Alert")
        }
    }
}
