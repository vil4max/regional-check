import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// Freshness, age and localization cases of the CarPlay Status screen, split from
/// `CarPlayTemplateBuilderTests` to keep each type inside the lint size limit.
extension CarPlayTemplateBuilderTests {
    @Test("REQ-REFRESH-007 a stale status from an earlier day shows its date with the time")
    func staleStatusFromAnEarlierDayShowsItsDate() {
        let status = makeStatus(region: .odesa, alarmRegions: [.odesa])
        let state = CarPlayLoadState.failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status))
        let checkedAt = state.snapshot?.checkedAt ?? .distantPast
        let timeOnly = String(
            format: String(localized: "driver.status.last_update"),
            checkedAt.formatted(date: .omitted, time: .shortened))

        let sameDay = statusBuilder(status).rootTemplate(loadState: state, freshness: freshness(advancedBy: 25 * 60))
        let nextDay = statusBuilder(status).rootTemplate(
            loadState: state, freshness: freshness(advancedBy: 36 * 3600))

        #expect(sameDay.items.first?.detail == timeOnly)
        #expect(nextDay.items.first?.detail != timeOnly)
        #expect(
            nextDay.items.first?.detail?.contains(checkedAt.formatted(date: .omitted, time: .shortened)) == true)
    }

    @Test("REQ-REFRESH-007 the freshness boundary: fresh at twice the interval, stale one second later")
    func freshnessBoundaryDecidesMarkerAndRows() {
        let status = makeStatus(region: .odesa, alarmRegions: [.odesa])
        let state = CarPlayLoadState.failed(cached: CarPlayRefreshCoordinator.cachedSnapshot(from: status))
        let checkedAt = state.snapshot?.checkedAt ?? .distantPast
        let offset = AppContainer.fixtureNow.timeIntervalSince(checkedAt)

        let atLimit = statusBuilder(status).rootTemplate(
            loadState: state, freshness: freshness(advancedBy: 120 - offset))
        let pastLimit = statusBuilder(status).rootTemplate(
            loadState: state, freshness: freshness(advancedBy: 121 - offset))

        #expect(atLimit.title == "🚨 Alert")
        #expect(pastLimit.title == "No Current Data")
    }

    @Test("REQ-REFRESH-007 loading with nothing cached says Updating, with no marker")
    func loadingWithoutCacheSaysUpdating() {
        let status = makeStatus(region: .kyivCity)

        let template = statusBuilder(status).rootTemplate(loadState: .loading(cached: nil), freshness: freshness())

        #expect(template.title == String(localized: "driver.updating"))
        #expect(template.items.count == 1)
    }

    @Test("REQ-SURF-006 a region missing from a fresh snapshot keeps its question mark and shows the region")
    func regionUnavailableKeepsItsMarker() {
        let status = makeStatus(region: .kyivCity)
        let snapshot = CarPlaySnapshot(
            state: .regionUnavailable, regionTitle: status.regionTitle, checkedAt: AppContainer.fixtureNow)

        let template = statusBuilder(status).rootTemplate(loadState: .loaded(snapshot), freshness: freshness())

        #expect(template.title.hasPrefix("? "))
        #expect(template.items.first?.title == status.regionTitle)
    }

    /// Reads the source catalog, where a key can be checked in every shipped locale at once. The
    /// bound is a literal: the longest CarPlay title (marker, space, word) must stay short enough
    /// for one glance and the template's single title line.
    @Test("REQ-SURF-001 every CarPlay status string exists in en, uk and ru and the titles stay short")
    func carPlayStringsAreLocalizedAndShort() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("RegionalCheck/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any]
        let strings = try #require(json?["strings"] as? [String: Any])
        let titleKeys = [
            "Alert Active", "All Clear", "status.caution.title", "driver.status.no_current_data.title",
            "driver.updating",
        ]
        let otherKeys = ["driver.status.last_update", "driver.region.outside", "location.access.denied.carplay"]

        for key in titleKeys + otherKeys {
            let entry = try #require(strings[key] as? [String: Any], "\(key) missing from the catalog")
            let localizations = try #require(entry["localizations"] as? [String: Any])
            for locale in ["en", "uk", "ru"] {
                let unit = (localizations[locale] as? [String: Any])?["stringUnit"] as? [String: Any]
                let value = try #require(unit?["value"] as? String, "\(key) missing for \(locale)")
                #expect(!value.isEmpty, "\(key) empty for \(locale)")
                if titleKeys.contains(key) {
                    #expect(value.count <= 24, "\(key) in \(locale) is too long for a glance: \(value)")
                }
            }
        }
    }
}
