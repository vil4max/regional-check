import DriveCheckKit
import Foundation
import Testing

struct ControlStatusValueBuilderTests {
    @Test
    func readsPhaseAndRegionFromSharedStore() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kharkiv)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "feed",
                    serverCachedAt: Date(timeIntervalSince1970: 50),
                    fetchedAt: Date(timeIntervalSince1970: 50),
                    statuses: [.kharkiv: .alarm]
                )
            )
            let value = ControlStatusValueBuilder.value(from: store)
            #expect(value.phase == .alarm)
            #expect(value.regionTitle == AlertRegion.kharkiv.title)
        }
    }

    @Test("REQ-SURF-010 the control shows the Stay Alert warning in yellow for a surrounded quiet region")
    func surroundedFreshShowsStayAlert() {
        let value = Self.value(
            statuses: [.kyivCity: .quiet, .kyivOblast: .alarm],
            age: 60
        )
        #expect(value.symbolName == "exclamationmark.triangle.fill")
        #expect(value.accent == .caution)
    }

    @Test("REQ-SURF-010 the control shows old data as the grey clock, never yellow or a checkmark")
    func staleSurroundedIsTheClock() {
        let value = Self.value(
            statuses: [.kyivCity: .quiet, .kyivOblast: .alarm],
            age: 3600
        )
        #expect(value.symbolName == "clock.fill")
        #expect(value.accent == .stale)
    }

    @Test("REQ-REFRESH-009 an old alarm keeps its own glyph on the control")
    func staleAlarmKeepsItsGlyph() {
        let value = Self.value(statuses: [.kyivCity: .alarm], age: 3600)
        #expect(value.symbolName == DriveCheckActivityPhase.alarm.symbolName)
        #expect(value.accent == .alert)
    }

    @Test("REQ-SURF-010 the control keeps the checkmark only for No Alert")
    func quietWithoutAlertsKeepsCheckmark() {
        let value = Self.value(statuses: [.kyivCity: .quiet], age: 60)
        #expect(value.symbolName == "checkmark.circle.fill")
        #expect(value.accent == .clear)
    }

    private static func value(statuses: [AlertRegion: AlertStatus], age: TimeInterval) -> ControlStatusValue {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let checkedAt = Date(timeIntervalSince1970: 1000)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "feed",
                    serverCachedAt: checkedAt,
                    fetchedAt: checkedAt,
                    statuses: statuses
                )
            )
            return ControlStatusValueBuilder.value(from: store, now: checkedAt.addingTimeInterval(age))
        }
    }
}
