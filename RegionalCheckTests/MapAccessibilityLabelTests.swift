import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct MapAccessibilityLabelTests {
    @Test
    func missingSnapshotYieldsUnavailableLabel() {
        let label = mapAccessibilityLabel(snapshot: nil)
        #expect(label == "Alert map. Status unavailable.")
    }

    @Test
    func quietSnapshotYieldsClearLabel() {
        let label = mapAccessibilityLabel(snapshot: TestSnapshots.quiet)
        #expect(label == "Alert map. All regions clear.")
    }

    @Test
    func alarmSnapshotListsAlarmedRegionsWithCount() {
        let label = mapAccessibilityLabel(snapshot: TestSnapshots.alarms([.lviv, .kharkiv]))
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
