import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// MAP-native AC-2, AC-4 and the stale decision: what colour each unit of the drawn map takes.
struct AlertMapFillTests {
    private static func snapshot(_ statuses: [AlertRegion: AlertStatus]) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "test", serverCachedAt: nil, fetchedAt: Date(timeIntervalSince1970: 1), statuses: statuses)
    }

    @Test("MAP-native AC-2 each region takes its fill from the snapshot the status uses")
    func regionsFollowTheSnapshot() {
        let snapshot = Self.snapshot([.kharkiv: .alarm, .lviv: .quiet])
        #expect(AlertMapFill.fill(for: .region(.kharkiv), snapshot: snapshot) == .alarm)
        #expect(AlertMapFill.fill(for: .region(.lviv), snapshot: snapshot) == .quiet)
        // A region the snapshot does not carry is not painted quiet.
        #expect(AlertMapFill.fill(for: .region(.odesa), snapshot: snapshot) == .noData)
    }

    @Test("MAP-native AC-2 Crimea and Sevastopol are always no data, whatever the regions show")
    func crimeaAndSevastopolHaveNoStatus() {
        let everyAlarm = Self.snapshot(Dictionary(uniqueKeysWithValues: AlertRegion.allCases.map { ($0, .alarm) }))
        #expect(AlertMapFill.fill(for: .crimea, snapshot: everyAlarm) == .noData)
        #expect(AlertMapFill.fill(for: .sevastopol, snapshot: everyAlarm) == .noData)
        #expect(AlertMapFill.fill(for: .region(.kherson), snapshot: everyAlarm) == .alarm)
    }

    @Test("MAP-native AC-4 without a snapshot every unit is no data")
    func noSnapshotIsNoData() {
        let units = AlertRegion.allCases.map(MapUnit.region) + [.crimea, .sevastopol]
        #expect(units.allSatisfy { AlertMapFill.fill(for: $0, snapshot: nil) == .noData })
    }

    @Test("MAP-native stale data dims the map instead of looking live")
    func staleDataDims() {
        #expect(AlertMapFill.opacity(isStale: false) == 1)
        #expect(AlertMapFill.opacity(isStale: true) < 1)
        #expect(AlertMapFill.opacity(isStale: true) > 0)
    }

    @Test("MAP-native AC-6 the drawn map is read as the regions under alert of the same snapshot")
    func voiceOverReadsTheSameSnapshot() {
        let snapshot = TestSnapshots.alarms([.kharkiv, .sumy])
        #expect(AlertMapCard.accessibilityText(snapshot: snapshot) == mapAccessibilityLabel(snapshot: snapshot))
        #expect(AlertMapCard.accessibilityText(snapshot: nil) == mapAccessibilityLabel(snapshot: nil))
    }
}
