import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct StatusNearbyLineTests {
    private static func snapshot(alarms: [AlertRegion]) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "test",
            serverCachedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            statuses: Dictionary(uniqueKeysWithValues: AlertRegion.allCases.map {
                ($0, alarms.contains($0) ? AlertStatus.alarm : .quiet)
            })
        )
    }

    @Test("REQ-SURF-005 the Status tab names a neighbour under alert while the region is quiet")
    func quietRegionWithANeighbourUnderAlert() {
        let text = TestLocale.english {
            StatusNearbyLine.text(region: .kyivCity, phase: .quiet, snapshot: Self.snapshot(alarms: [.chernihiv]))
        }
        #expect(text == "Nearby: \(AlertRegion.chernihiv.title)")
    }

    @Test("REQ-SURF-005 the Status tab keeps the nearby line while the region itself is in alarm")
    func alarmRegionStillShowsNeighbours() {
        let text = StatusNearbyLine.text(
            region: .kyivCity,
            phase: .alarm,
            snapshot: Self.snapshot(alarms: [.kyivCity, .kyivOblast])
        )
        #expect(text?.contains(AlertRegion.kyivOblast.title) == true)
        #expect(text?.contains(AlertRegion.kyivCity.title) == false)
    }

    @Test("REQ-SURF-005 the nearby line does not depend on the summary being current")
    func lineIsComputedFromTheSnapshotAlone() {
        // The summary withholds claims while data is stale; this line reads the snapshot the hero
        // is already showing as last known, so staleness is not an input at all.
        let text = StatusNearbyLine.text(region: .lviv, phase: .quiet, snapshot: Self.snapshot(alarms: [.volyn]))
        #expect(text != nil)
    }

    @Test
    func noLineWithoutANeighbourUnderAlert() {
        let text = StatusNearbyLine.text(region: .lviv, phase: .quiet, snapshot: Self.snapshot(alarms: [.kharkiv]))
        #expect(text == nil)
    }

    @Test
    func noLineWithoutAStatusToQualify() {
        let snapshot = Self.snapshot(alarms: [.kyivOblast])
        #expect(StatusNearbyLine.text(region: .kyivCity, phase: .idle, snapshot: snapshot) == nil)
        #expect(StatusNearbyLine.text(region: .kyivCity, phase: .error, snapshot: snapshot) == nil)
        #expect(StatusNearbyLine.text(region: .kyivCity, phase: .quiet, snapshot: nil) == nil)
    }
}
