import DriveCheckKit
import Testing

/// RD-10 row 9: the accent a Live Activity or Home Screen widget renders a phase with.
struct WidgetPresentationAccentTests {
    @Test("REQ-REFRESH-009 a known alarm stays alert-accented at any freshness")
    func alarmNeverDowngrades() {
        #expect(DriveCheckActivityPhase.alarm.presentationAccent(isStale: false) == .alert)
        #expect(DriveCheckActivityPhase.alarm.presentationAccent(isStale: true) == .alert)
    }

    @Test("Failure condition: a stale quiet status never shows the clear accent")
    func staleQuietDropsClearAccent() {
        #expect(DriveCheckActivityPhase.quiet.presentationAccent(isStale: false) == .clear)
        #expect(DriveCheckActivityPhase.quiet.presentationAccent(isStale: true) == .stale)
    }

    @Test("Idle and error phases are always the neutral checking accent")
    func idleAndErrorAreNeutral() {
        #expect(DriveCheckActivityPhase.idle.presentationAccent(isStale: false) == .checking)
        #expect(DriveCheckActivityPhase.error.presentationAccent(isStale: true) == .checking)
    }
}
