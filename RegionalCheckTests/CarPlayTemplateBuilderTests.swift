import CarPlay
import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// CarPlay templates built from a held status snapshot, asserting what a driver sees without a
/// connected CarPlay scene.
@MainActor
struct CarPlayTemplateBuilderTests {

    // MARK: - Status screen

    @Test("REQ-SURF-001 quiet title uses the full form and marker")
    func quietTitleUsesFullFormAndMarker() {
        let status = makeStatus(region: .kyivCity, alarmRegions: [])

        let template = statusBuilder(status).rootTemplate(loadState: loaded(status), freshness: freshness())

        #expect(template.title == "🟢 No Alert")
        #expect(template.items.first?.title == status.regionTitle)
        // The region follows location only, so no mode word precedes the time: "Automatic"
        // would distinguish nothing and would be claimed even with location denied.
        #expect(template.items.first?.detail?.hasPrefix("Updated ") == true)
        #expect(template.items.first?.detail?.contains("Automatic") == false)
    }

    @Test("REQ-SURF-001 alarm title uses the full form, not the short pill word")
    func alarmTitleUsesFullForm() {
        let status = makeStatus(region: .kharkiv, alarmRegions: [.kharkiv])
        let state = loaded(status)

        let template = statusBuilder(status).rootTemplate(loadState: state, freshness: freshness())

        #expect(template.title == "🚨 Air Raid Alert")
        #expect(state.snapshot?.state.title == "Alert")  // the short form stays unchanged elsewhere
    }

    @Test("REQ-SURF-005 nearby row shows in the alarm phase too, not only quiet")
    func nearbyRowShowsDuringAlarm() {
        let status = makeStatus(region: .kharkiv, alarmRegions: [.kharkiv, .sumy])

        let template = statusBuilder(status).rootTemplate(loadState: loaded(status), freshness: freshness())

        #expect(template.items.contains { $0.title == "Nearby: Sumy Oblast" })
    }

    @Test("REQ-SURF-005 nearby row title caps at 2 names plus a +N badge, with no detail line")
    func nearbyRowCapsNamesAtTwo() {
        let status = makeStatus(region: .poltava, alarmRegions: [.poltava, .kyivOblast, .chernihiv, .sumy])

        let template = statusBuilder(status).rootTemplate(loadState: loaded(status), freshness: freshness())

        #expect(
            template.items.contains {
                $0.title == "Nearby: Kyiv Oblast, Chernihiv Oblast +1" && $0.detail == nil
            })
    }

    @Test("REQ-SURF-006 with nothing nearby the screen is the region and its update time alone")
    func quietScreenIsRegionAndUpdateTimeOnly() {
        let status = makeStatus(region: .kyivCity, alarmRegions: [])

        let template = statusBuilder(status).rootTemplate(loadState: loaded(status), freshness: freshness())

        #expect(template.items.count == 1)
        #expect(template.items.first?.title == status.regionTitle)
        #expect(template.items.first?.detail?.hasPrefix("Updated ") == true)
    }

    @Test("REQ-SURF-006 no country count, region sentence or source row, even with alerts nearby")
    func screenCarriesNoSecondaryRows() {
        let status = makeStatus(region: .poltava, alarmRegions: [.poltava, .kyivOblast, .chernihiv, .sumy])

        let template = statusBuilder(status).rootTemplate(loadState: loaded(status), freshness: freshness())

        #expect(template.items.count == 2)
        #expect(!template.items.contains { $0.title?.hasPrefix("Source:") == true })
        #expect(!template.items.contains { $0.detail?.contains("of 25") == true })
    }

    @Test("REQ-REFRESH-007 a failed request with a fresh cache keeps the cached status in the title")
    func failedRefreshWithFreshCacheKeepsCachedStatusInTitle() {
        let status = makeStatus(region: .odesa, alarmRegions: [.odesa])
        status.hasRefreshFailed = true
        let state = CarPlayLoadState.failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status))

        let template = statusBuilder(status).rootTemplate(loadState: state, freshness: freshness())

        #expect(template.title == "🚨 Air Raid Alert")
    }

    @Test("REQ-REFRESH-007 a stale cached status shows no current data and no marker")
    func staleCacheShowsNoCurrentDataWithoutMarker() {
        let status = makeStatus(region: .odesa, alarmRegions: [.odesa])
        status.hasRefreshFailed = true
        let state = CarPlayLoadState.failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status))

        let template = statusBuilder(status).rootTemplate(loadState: state, freshness: freshness(advancedBy: 25 * 60))

        #expect(template.title == "No Current Data")
        #expect(
            template.items.contains {
                $0.title == "Last known status: Alert" && $0.detail == "Data may be outdated — refresh"
            })
    }

    @Test("REQ-SURF-006 Refresh is the only action")
    func refreshIsTheOnlyAction() {
        let status = makeStatus(region: .kyivCity)
        let state = CarPlayLoadState.loading(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status))

        let template = statusBuilder(status).rootTemplate(loadState: state, freshness: freshness())

        #expect(template.actions.map(\.title) == ["Checking…"])
    }

    @Test("REQ-REGION-009 location denied shows short CarPlay text instead of the nearby row")
    func locationDeniedShowsShortTextInsteadOfNearbyRow() {
        let status = makeStatus(region: .kyivCity, alarmRegions: [])
        let builder = statusBuilder(status, location: FixtureLocationManager(authorizationStatus: .denied))

        let template = builder.rootTemplate(loadState: loaded(status), freshness: freshness())

        #expect(
            template.items.contains {
                $0.title == "Location access off — enable it on iPhone" && $0.detail == nil
            })
        #expect(!template.items.contains { $0.title?.hasPrefix("Nearby") == true || $0.title == "Nothing nearby" })
    }

    @Test("The Status screen stays inside CPInformationTemplate's 10-item and 3-action limits")
    func statusScreenStaysInsideTemplateLimits() {
        let status = makeStatus(region: .poltava, alarmRegions: [.poltava, .kyivOblast, .chernihiv, .sumy])

        let template = statusBuilder(status).rootTemplate(loadState: loaded(status), freshness: freshness())

        #expect(template.items.count <= 10)
        #expect(template.actions.count <= 3)
    }

    @Test("Outside Ukraine the region row says so instead of an update time")
    func outsideUkraineReplacesTheUpdateTime() {
        let status = makeStatus(region: .kyivCity, alarmRegions: [])
        let regions = FakeCarPlayRegions()
        regions.isOutsideUkraine = true

        let template = statusBuilder(status, regions: regions)
            .rootTemplate(loadState: loaded(status), freshness: freshness())

        #expect(template.items.first?.detail == String(localized: "driver.region.outside"))
    }
}

// MARK: - Helpers

extension CarPlayTemplateBuilderTests {
    private func makeStatus(
        region: AlertRegion,
        alarmRegions: Set<AlertRegion> = [.kharkiv, .sumy, .donetsk, .zaporizhzhia]
    ) -> FakeCarPlayStatus {
        FakeCarPlayStatus(region: region, snapshot: FixtureNetwork.snapshot(alarmRegions: alarmRegions))
    }

    private func loaded(_ status: FakeCarPlayStatus) -> CarPlayLoadState {
        CarPlayRefreshCoordinator.cachedSnapshot(from: status).map { .loaded($0) } ?? .failed(cached: nil)
    }

    private func freshness(advancedBy seconds: TimeInterval = 0) -> CarPlayFreshness {
        CarPlayFreshness(now: AppContainer.fixtureNow.addingTimeInterval(seconds), refreshIntervalSeconds: 60)
    }

    private func statusBuilder(
        _ status: FakeCarPlayStatus,
        regions: FakeCarPlayRegions = FakeCarPlayRegions(),
        location: FixtureLocationManager = FixtureLocationManager()
    ) -> CarPlayTemplateBuilder {
        CarPlayTemplateBuilder(status: status, regions: regions, location: location, onRefresh: {})
    }
}
