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
            statuses: Dictionary(
                uniqueKeysWithValues: AlertRegion.allCases.map {
                    ($0, alarms.contains($0) ? AlertStatus.alarm : .quiet)
                })
        )
    }

    @Test("REQ-SURF-005 UI-simplify AC-2 the Status tab names a neighbour under alert while the region is quiet")
    func quietRegionWithANeighbourUnderAlert() {
        let text = StatusNearbyLine.names(
            region: .kyivCity,
            phase: .quiet,
            snapshot: Self.snapshot(alarms: [.chernihiv])
        )
        #expect(text == AlertRegion.chernihiv.title)
    }

    @Test("REQ-SURF-005 UI-simplify AC-2 the Status tab keeps the nearby row while the region itself is in alarm")
    func alarmRegionStillShowsNeighbours() {
        // Exact match, not `contains`: "Kyiv" is a substring of "Kyiv Oblast", so a substring
        // check cannot tell the region itself from its neighbour.
        let text = StatusNearbyLine.names(
            region: .kyivCity,
            phase: .alarm,
            snapshot: Self.snapshot(alarms: [.kyivCity, .kyivOblast])
        )
        #expect(text == AlertRegion.kyivOblast.title)
    }

    @Test
    func noLineWithoutANeighbourUnderAlert() {
        let text = StatusNearbyLine.names(region: .lviv, phase: .quiet, snapshot: Self.snapshot(alarms: [.kharkiv]))
        #expect(text == nil)
    }

    @Test
    func noLineWithoutAStatusToQualify() {
        let snapshot = Self.snapshot(alarms: [.kyivOblast])
        #expect(StatusNearbyLine.names(region: .kyivCity, phase: .idle, snapshot: snapshot) == nil)
        #expect(StatusNearbyLine.names(region: .kyivCity, phase: .error, snapshot: snapshot) == nil)
        #expect(StatusNearbyLine.names(region: .kyivCity, phase: .quiet, snapshot: nil) == nil)
    }

    @Test("UI-simplify AC-3 the regions row counts the regions under alert out of all 25")
    func regionsRowCountsAlarms() {
        #expect(StatusRegionsCount.text(snapshot: Self.snapshot(alarms: [.kharkiv, .sumy])) == "2 of 25")
        #expect(StatusRegionsCount.text(snapshot: Self.snapshot(alarms: [])) == "0 of 25")
        #expect(StatusRegionsCount.text(snapshot: nil) == nil)
    }
}
