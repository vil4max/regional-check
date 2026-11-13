import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// STATUS-two-states AC-9: "All clear at 11:57 · the alert lasted 49 min" for 30 minutes after the
/// all-clear the app saw, while the region is quiet and no neighbour is under alert.
@MainActor
struct AllClearLineTests {
    private static let start = Date(timeIntervalSince1970: 1_789_550_000)
    private static let allClear = start.addingTimeInterval(49 * 60)

    private static func snapshot(_ statuses: [AlertRegion: AlertStatus], at date: Date, start: Date? = nil)
        -> AlertsSnapshot
    {
        AlertsSnapshot(
            source: "test", serverCachedAt: date, fetchedAt: date, statuses: statuses,
            alarmStartedAt: start.map { [.kyivCity: $0] })
    }

    @Test("STATUS-two-states AC-9 the app records an all-clear only when it sees the alert end")
    func recordsOnlyTheObservedTransition() {
        let alarm = Self.snapshot([.kyivCity: .alarm], at: Self.allClear.addingTimeInterval(-60), start: Self.start)
        let quiet = Self.snapshot([.kyivCity: .quiet], at: Self.allClear)

        let record = AllClearRecord.next(nil, region: .kyivCity, previous: alarm, current: quiet)
        #expect(record == AllClearRecord(region: .kyivCity, allClearAt: Self.allClear, alertStartedAt: Self.start))
        #expect(record?.durationMinutes == 49)

        // Quiet after quiet keeps it; a new alert drops it; quiet without an observed alert records nothing.
        let later = Self.snapshot([.kyivCity: .quiet], at: Self.allClear.addingTimeInterval(300))
        #expect(AllClearRecord.next(record, region: .kyivCity, previous: quiet, current: later) == record)
        #expect(AllClearRecord.next(record, region: .kyivCity, previous: quiet, current: alarm) == nil)
        #expect(AllClearRecord.next(nil, region: .kyivCity, previous: quiet, current: later) == nil)
        #expect(AllClearRecord.next(nil, region: .kyivCity, previous: nil, current: quiet) == nil)
    }

    @Test("STATUS-two-states AC-9 an alert last seen over 10 minutes before the quiet check records nothing")
    func aGapIsNotAnObservedAllClear() {
        let quiet = Self.snapshot([.kyivCity: .quiet], at: Self.allClear)
        let justInside = Self.snapshot(
            [.kyivCity: .alarm], at: Self.allClear.addingTimeInterval(-600), start: Self.start)
        let beyond = Self.snapshot(
            [.kyivCity: .alarm], at: Self.allClear.addingTimeInterval(-601), start: Self.start)
        let older = AllClearRecord(region: .kyivCity, allClearAt: Self.start, alertStartedAt: nil)
        let elsewhere = AllClearRecord(region: .lviv, allClearAt: Self.start, alertStartedAt: nil)

        #expect(
            AllClearRecord.next(nil, region: .kyivCity, previous: justInside, current: quiet)?.allClearAt
                == Self.allClear)
        #expect(AllClearRecord.next(nil, region: .kyivCity, previous: beyond, current: quiet) == nil)
        // The region's own older record is about an earlier alert, so it goes; another region's stays.
        #expect(AllClearRecord.next(older, region: .kyivCity, previous: beyond, current: quiet) == nil)
        #expect(AllClearRecord.next(elsewhere, region: .kyivCity, previous: beyond, current: quiet) == elsewhere)
    }

    private static func line(_ record: AllClearRecord?, at checkedAt: Date, alarms: [AlertRegion] = []) -> String? {
        var statuses: [AlertRegion: AlertStatus] = [.kyivCity: .quiet]
        for region in alarms { statuses[region] = .alarm }
        return StatusReasonLine.text(
            region: .kyivCity, phase: .quiet, snapshot: snapshot(statuses, at: checkedAt),
            alarmStartedAt: nil, checkedAt: checkedAt, allClear: record)
    }

    @Test("STATUS-two-states AC-9 the line names the time and the duration for 30 minutes")
    func lineShowsForThirtyMinutes() {
        let record = AllClearRecord(region: .kyivCity, allClearAt: Self.allClear, alertStartedAt: Self.start)
        let time = DayAwareTime.text(Self.allClear, reference: Self.allClear)
        let expected = String(format: String(localized: "status.reason.allclear"), time, 49)

        #expect(Self.line(record, at: Self.allClear) == expected)
        #expect(Self.line(record, at: Self.allClear.addingTimeInterval(29 * 60)) == expected)
        #expect(Self.line(record, at: Self.allClear.addingTimeInterval(30 * 60)) == nil)
    }

    @Test("STATUS-two-states AC-9 the nearby note wins, and another region's record is not shown")
    func nearbyWinsAndRegionMatters() {
        let record = AllClearRecord(region: .kyivCity, allClearAt: Self.allClear, alertStartedAt: Self.start)
        let nearby = Self.line(record, at: Self.allClear, alarms: [.kyivOblast])
        #expect(nearby == String(format: String(localized: "status.reason.nearby"), AlertRegion.kyivOblast.title))

        let other = AllClearRecord(region: .lviv, allClearAt: Self.allClear, alertStartedAt: Self.start)
        #expect(Self.line(other, at: Self.allClear) == nil)
    }

    @Test("STATUS-two-states AC-9 without a known start the line gives the time alone")
    func unknownStartGivesTheTimeAlone() {
        let record = AllClearRecord(region: .kyivCity, allClearAt: Self.allClear, alertStartedAt: nil)
        let time = DayAwareTime.text(Self.allClear, reference: Self.allClear)
        #expect(
            Self.line(record, at: Self.allClear)
                == String(format: String(localized: "status.reason.allclear.time"), time))
    }

    @Test("STATUS-two-states AC-9 the controller records the all-clear and keeps it across launches")
    func controllerRecordsAndRestores() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults, legacyDefaults: defaults)
            let records = AllClearRecordStore(userDefaults: defaults)
            store.saveSnapshot(
                Self.snapshot([.kyivCity: .alarm], at: Self.allClear.addingTimeInterval(-60), start: Self.start))
            let controller = StatusController(
                region: .kyivCity,
                provider: MockStatusProvider(snapshot: Self.snapshot([.kyivCity: .quiet], at: Self.allClear)),
                environmentProvider: FixtureRefreshEnvironment(),
                persistence: store,
                widgetReloader: TestWidgetReloader(),
                allClearStore: records,
                now: { Self.allClear }
            )

            await controller.refresh()

            let expected = AllClearRecord(region: .kyivCity, allClearAt: Self.allClear, alertStartedAt: Self.start)
            #expect(controller.allClearRecord == expected)
            #expect(records.load() == expected)

            let relaunched = StatusController(
                region: .kyivCity,
                provider: MockStatusProvider(snapshot: Self.snapshot([.kyivCity: .quiet], at: Self.allClear)),
                environmentProvider: FixtureRefreshEnvironment(),
                persistence: store,
                widgetReloader: TestWidgetReloader(),
                allClearStore: records
            )
            #expect(relaunched.allClearRecord == expected)
        }
    }

    @Test("STATUS-two-states AC-9 reopening the app hours after the alert records no all-clear")
    func relaunchAfterAGapRecordsNothing() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults, legacyDefaults: defaults)
            let records = AllClearRecordStore(userDefaults: defaults)
            let opened = Self.allClear.addingTimeInterval(3 * 3600)
            store.saveSnapshot(
                Self.snapshot([.kyivCity: .alarm], at: Self.start.addingTimeInterval(600), start: Self.start))
            let controller = StatusController(
                region: .kyivCity,
                provider: MockStatusProvider(snapshot: Self.snapshot([.kyivCity: .quiet], at: opened)),
                environmentProvider: FixtureRefreshEnvironment(),
                persistence: store,
                widgetReloader: TestWidgetReloader(),
                allClearStore: records,
                now: { opened }
            )

            await controller.refresh()

            #expect(controller.allClearRecord == nil)
            #expect(records.load() == nil)
        }
    }
}
