import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The shared nearby-alerts line and the user text built from one format key per line.
@MainActor
struct NearbyAlertsLineTests {
    private static func snapshot(alarms: [AlertRegion]) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "test",
            serverCachedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            statuses: Dictionary(
                uniqueKeysWithValues: AlertRegion.allCases.map {
                    ($0, alarms.contains($0) ? AlertStatus.alarm : .quiet)
                })
        )
    }

    @Test("REQ-SURF-005 one nearby line names two neighbours, then a +N badge")
    func namesTwoThenABadge() {
        let text = NearbyAlertsLine.text(
            region: .kyivCity,
            snapshot: Self.snapshot(alarms: [.kyivOblast, .chernihiv, .zhytomyr])
        )
        #expect(text == "Nearby: \(AlertRegion.kyivOblast.title), \(AlertRegion.chernihiv.title) +1")
        #expect(NearbyAlertsLine.text(region: .kyivCity, snapshot: nil) == nil)
        #expect(NearbyAlertsLine.text(region: .lviv, snapshot: Self.snapshot(alarms: [.kharkiv])) == nil)
    }

    @Test("Every reworded key has English, Ukrainian and Russian text")
    func reworkedKeysAreTranslated() {
        let keys = [
            "driver.status.nearby_line", "driver.status.nearby_names_more", "driver.last_status_line",
            "location.access.denied.carplay", "country.summary.partial_clear",
        ]
        for language in ["en", "uk", "ru"] {
            let bundle = AppLocalization.bundle(for: Locale(identifier: language))
            for key in keys {
                let value = bundle.localizedString(forKey: key, value: "MISSING", table: nil)
                #expect(value != "MISSING" && value != key, "\(language): \(key)")
            }
        }
    }

    @Test("The partial-coverage country line agrees with its count in every language")
    func partialClearPlurals() async throws {
        let cases: [(String, Int, String)] = [
            ("en", 1, "in the 1 region reporting data"),
            ("en", 2, "in the 2 regions reporting data"),
            ("uk", 1, "У 1 регіоні, щодо якого"),
            ("uk", 21, "У 21 регіоні, щодо якого"),
            ("uk", 3, "У 3 регіонах, щодо яких"),
            ("uk", 11, "У 11 регіонах, щодо яких"),
            ("ru", 1, "В 1 регионе, по которому"),
            ("ru", 21, "В 21 регионе, по которому"),
            ("ru", 5, "В 5 регионах, по которым"),
        ]
        for (language, clearCount, expected) in cases {
            let summary = try await DeterministicStatusDetailsProvider().summary(
                for: try Self.partialInput(language: language, clearCount: clearCount)
            )
            #expect(summary.contains(expected), "\(language) \(clearCount): \(summary)")
        }
    }

    private static func partialInput(language: String, clearCount: Int) throws -> StatusDetailsInput {
        let base = try StatusDetailsTestSupport.makeInput(localeIdentifier: language, rawSource: "feed")
        let total = AlertRegion.allCases.count
        let aggregate = CountrySituationAggregate(
            totalRegions: total,
            alerts: [],
            unavailable: Array(AlertRegion.allCases.prefix(total - clearCount)),
            clearCount: clearCount
        )
        return StatusDetailsInput(
            region: base.region,
            countryAggregate: aggregate,
            countryContext: base.countryContext,
            localeIdentifier: language
        )
    }
}
