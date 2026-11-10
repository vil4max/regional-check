import DriveCheckKit
import Testing

/// ALERT-push AC-10: each Live Activity state has a symbol of its own shape, so the Lock Screen,
/// the Dynamic Island, the Watch and the Mac tell the states apart without colour or words.
struct LiveActivityGlyphTests {
    @Test("ALERT-push AC-10 alert is a siren, and an alert on old data keeps it with a clock badge")
    func alarmIsASiren() {
        #expect(
            DriveCheckActivityPhase.alarm.liveActivityGlyph(isStale: false)
                == LiveActivityGlyph(symbolName: "light.beacon.max.fill", badgeSymbolName: nil))
        #expect(
            DriveCheckActivityPhase.alarm.liveActivityGlyph(isStale: true)
                == LiveActivityGlyph(symbolName: "light.beacon.max.fill", badgeSymbolName: "clock.fill"))
    }

    @Test("ALERT-push AC-10 all clear is a shield with a check; old quiet data is the clock alone")
    func allClearIsAShield() {
        #expect(
            DriveCheckActivityPhase.quiet.liveActivityGlyph(isStale: false)
                == LiveActivityGlyph(symbolName: "checkmark.shield.fill", badgeSymbolName: nil))
        #expect(
            DriveCheckActivityPhase.quiet.liveActivityGlyph(isStale: true)
                == LiveActivityGlyph(symbolName: "clock.fill", badgeSymbolName: nil))
    }

    @Test("ALERT-push AC-10 checking and unavailable keep the shared symbols")
    func otherPhasesKeepTheSharedSymbols() {
        #expect(
            DriveCheckActivityPhase.idle.liveActivityGlyph(isStale: true)
                == LiveActivityGlyph(symbolName: "arrow.triangle.2.circlepath", badgeSymbolName: nil))
        #expect(
            DriveCheckActivityPhase.error.liveActivityGlyph(isStale: false)
                == LiveActivityGlyph(symbolName: "questionmark.circle.fill", badgeSymbolName: nil))
        #expect(
            DriveCheckActivityPhase.error.liveActivityGlyph(isStale: true)
                == LiveActivityGlyph(symbolName: "clock.fill", badgeSymbolName: nil))
    }

    @Test("ALERT-push AC-10 every state the Live Activity can show has a different symbol")
    func statesDifferByShape() {
        let symbols = [
            DriveCheckActivityPhase.alarm.liveActivityGlyph(isStale: false).symbolName,
            DriveCheckActivityPhase.quiet.liveActivityGlyph(isStale: false).symbolName,
            DriveCheckActivityPhase.quiet.liveActivityGlyph(isStale: true).symbolName,
            DriveCheckActivityPhase.idle.liveActivityGlyph(isStale: false).symbolName,
        ]
        #expect(Set(symbols).count == symbols.count)
    }
}
