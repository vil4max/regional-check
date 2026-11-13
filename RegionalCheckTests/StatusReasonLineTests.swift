import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// STATUS-reason: the one line under the status that says why it is what it is.
@MainActor
struct StatusReasonLineTests {
    private static let checkedAt = Date(timeIntervalSince1970: 1_789_555_260)

    private static func snapshot(alarms: [AlertRegion], startedAt: [AlertRegion: Date]? = nil) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "test",
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: Dictionary(
                uniqueKeysWithValues: AlertRegion.allCases.map {
                    ($0, alarms.contains($0) ? AlertStatus.alarm : .quiet)
                }),
            alarmStartedAt: startedAt
        )
    }

    private static func nearby(_ names: String) -> String {
        String(format: String(localized: "status.reason.nearby"), names)
    }

    private static func since(_ start: Date) -> String {
        String(format: String(localized: "status.reason.since"), DayAwareTime.text(start, reference: checkedAt))
    }

    private static func reason(
        _ region: AlertRegion, _ phase: StatusState.Phase, _ snapshot: AlertsSnapshot?
    ) -> String? {
        StatusReasonLine.text(
            region: region,
            phase: phase,
            snapshot: snapshot,
            alarmStartedAt: snapshot?.alarmStart(for: region),
            checkedAt: checkedAt
        )
    }

    @Test("REQ-SURF-005 STATUS-reason AC-1 a quiet region with neighbours under alert names them")
    func quietRegionNamesItsNeighbours() {
        let surrounded = Self.snapshot(alarms: [.kyivOblast, .chernihiv, .zhytomyr, .cherkasy])
        let expectedNames = NearbyAlertsLine.names(NearbyAlertsLine.regions(near: .kyivOblast, snapshot: surrounded))
        #expect(expectedNames.contains("+"))
        #expect(Self.reason(.kyivOblast, .quiet, surrounded) == Self.nearby(expectedNames))

        // One neighbour under alert is enough for the line.
        let one = Self.snapshot(alarms: [.chernihiv])
        #expect(Self.reason(.kyivCity, .quiet, one) == Self.nearby(AlertRegion.chernihiv.title))

        #expect(Self.reason(.lviv, .quiet, Self.snapshot(alarms: [.kharkiv])) == nil)
    }

    @Test("REQ-SURF-014 STATUS-reason AC-2 an alert in the region shows its start, not the neighbours")
    func alarmShowsItsStart() {
        let sameDay = Self.checkedAt.addingTimeInterval(-25 * 60)
        let alarm = Self.snapshot(alarms: [.kyivCity, .kyivOblast], startedAt: [.kyivCity: sameDay])
        let line = Self.reason(.kyivCity, .alarm, alarm)
        #expect(line == Self.since(sameDay))
        #expect(line?.contains(AlertRegion.kyivOblast.title) == false)

        let unknownStart = Self.snapshot(alarms: [.kyivCity, .kyivOblast])
        #expect(Self.reason(.kyivCity, .alarm, unknownStart) == nil)
    }

    @Test("STATUS-reason AC-2 a start on an earlier day than the check carries its date")
    func startOnAnEarlierDayCarriesItsDate() throws {
        var calendar = Calendar.current
        calendar.timeZone = .current
        let dayBefore = try #require(calendar.date(byAdding: .day, value: -1, to: Self.checkedAt))
        let line = try #require(
            Self.reason(.kyivCity, .alarm, Self.snapshot(alarms: [.kyivCity], startedAt: [.kyivCity: dayBefore])))
        let timeOnly = dayBefore.formatted(date: .omitted, time: .shortened)
        #expect(line.contains(timeOnly))
        #expect(line != String(format: String(localized: "status.reason.since"), timeOnly))
    }

    @Test("STATUS-reason AC-3 no reason line while checking, on an error, without a region or a snapshot")
    func noReasonInOtherPhases() {
        let snapshot = Self.snapshot(alarms: [.kyivCity, .kyivOblast], startedAt: [.kyivCity: Self.checkedAt])
        for phase in [StatusState.Phase.idle, .error, .regionUnavailable] {
            #expect(Self.reason(.kyivCity, phase, snapshot) == nil)
        }
        #expect(Self.reason(.kyivCity, .quiet, nil) == nil)
        #expect(Self.reason(.kyivCity, .alarm, nil) == nil)
    }

    @Test("STATUS-reason AC-6 the line reads the snapshot whatever its age")
    func staleDataKeepsTheReason() {
        // The phase and snapshot are the last known ones: an hour-old check still gives the line,
        // because the gate is the phase, not the stale accent. The Live Activity shows a start only
        // for a fresh alarm (REQ-SURF-014); the phone keeps it because its meta line states the age.
        let staleCheck = Self.checkedAt.addingTimeInterval(-3600)
        let quiet = Self.snapshot(alarms: [.kyivOblast])
        #expect(
            StatusReasonLine.text(
                region: .kyivCity, phase: .quiet, snapshot: quiet, alarmStartedAt: nil, checkedAt: staleCheck)
                == Self.nearby(AlertRegion.kyivOblast.title))

        let start = staleCheck.addingTimeInterval(-600)
        let alarm = Self.snapshot(alarms: [.kyivCity], startedAt: [.kyivCity: start])
        #expect(
            StatusReasonLine.text(
                region: .kyivCity, phase: .alarm, snapshot: alarm, alarmStartedAt: start, checkedAt: staleCheck)
                != nil)
    }
}

struct DayAwareTimeTests {
    @Test("STATUS-reason R4 the same day gives the time alone, an earlier day adds day and month")
    func sameDayAndEarlierDay() throws {
        let reference = Date(timeIntervalSince1970: 1_789_555_260)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: reference)
        let sameDay = startOfDay.addingTimeInterval(60)
        let dayBefore = startOfDay.addingTimeInterval(-60)

        #expect(DayAwareTime.text(sameDay, reference: reference) == sameDay.formatted(date: .omitted, time: .shortened))
        #expect(
            DayAwareTime.text(dayBefore, reference: reference)
                == dayBefore.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
        #expect(!DayAwareTime.text(dayBefore, reference: reference).contains(dayBefore.formatted(.dateTime.year())))
    }
}
