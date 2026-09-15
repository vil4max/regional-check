import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct MapImageSourceTests {
    @Test
    func dayVariantBuildsDefaultMapURL() {
        #expect(MapImageSource.url(for: .day).absoluteString == "https://ubilling.net.ua/aerialalerts/?map=true")
    }

    @Test
    func nightVariantBuildsNightModeMapURL() {
        #expect(MapImageSource.url(for: .night).absoluteString == "https://ubilling.net.ua/aerialalerts/?map=nightmode")
    }
}

struct MapAccessibilityLabelTests {
    @Test
    func missingSnapshotYieldsUnavailableLabel() throws {
        let label = try TestLocale.english {
            mapAccessibilityLabel(snapshot: nil)
        }
        #expect(label == "Alert map. Status unavailable.")
    }

    @Test
    func quietSnapshotYieldsClearLabel() throws {
        let label = try TestLocale.english {
            mapAccessibilityLabel(snapshot: TestSnapshots.quiet)
        }
        #expect(label == "Alert map. All regions clear.")
    }

    @Test
    func alarmSnapshotListsAlarmedRegionsWithCount() throws {
        let label = try TestLocale.english {
            mapAccessibilityLabel(snapshot: TestSnapshots.alarms([.lviv, .kharkiv]))
        }
        let expectedNames = [AlertRegion.kharkiv, .lviv]
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            .map(\.title)
            .joined(separator: ", ")
        #expect(label == "Alert map. Regions in alert (2): \(expectedNames)")
    }
}

enum TestSnapshots {
    static let quiet = AlertsSnapshot(
        source: "test",
        serverCachedAt: nil,
        fetchedAt: Date(timeIntervalSince1970: 1),
        statuses: [.kyivCity: .quiet, .lviv: .quiet]
    )

    static func alarms(_ regions: [AlertRegion]) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "test",
            serverCachedAt: nil,
            fetchedAt: Date(timeIntervalSince1970: 1),
            statuses: Dictionary(uniqueKeysWithValues: regions.map { ($0, .alarm) })
        )
    }
}
