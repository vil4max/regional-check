import DriveCheckKit
import Foundation
import Testing

/// REQ-SURF-014 with ALERT-push AC-10: everything a Live Activity draws for a state, in one row per
/// state, so a regression in one place (a stale alarm losing its red or symbol, a duration that
/// keeps counting on old data) fails here. The widget views only lay these out.
struct LiveActivityStateMatrixTests {
    struct Row: CustomTestStringConvertible, Sendable {
        let name: String
        let phase: DriveCheckActivityPhase
        let isStale: Bool
        let symbol: String
        let badge: String?
        let accent: WidgetPresentationAccent
        let footer: LiveActivityFooter?
        let showsStart: Bool

        var testDescription: String { name }
    }

    private static let startedAt = Date(timeIntervalSinceReferenceDate: 816_175_000)
    private static let checkedAt = Date(timeIntervalSinceReferenceDate: 816_175_714)

    static let rows: [Row] = [
        Row(
            name: "fresh alarm", phase: .alarm, isStale: false, symbol: "light.beacon.max.fill",
            badge: nil, accent: .alert, footer: nil, showsStart: true),
        Row(
            name: "stale alarm", phase: .alarm, isStale: true, symbol: "light.beacon.max.fill",
            badge: "clock.fill", accent: .alert, footer: .mayBeOutdated, showsStart: false),
        Row(
            name: "all clear", phase: .quiet, isStale: false, symbol: "checkmark.shield.fill",
            badge: nil, accent: .clear, footer: nil, showsStart: false),
        Row(
            name: "stale all clear", phase: .quiet, isStale: true, symbol: "clock.fill",
            badge: nil, accent: .stale, footer: .lastKnown, showsStart: false),
        Row(
            name: "checking", phase: .idle, isStale: false,
            symbol: DriveCheckActivityPhase.idle.liveActivityGlyph(isStale: false).symbolName,
            badge: nil, accent: .checking, footer: .checking, showsStart: false),
    ]

    @Test("REQ-SURF-014 each Live Activity state keeps its symbol, colour, footer and duration rule", arguments: rows)
    func stateRow(_ row: Row) {
        let state = DriveCheckActivityAttributes.ContentState(
            phase: row.phase, regionTitle: "Kyiv", checkedAt: Self.checkedAt, sourceLabel: "",
            alertStartedAt: Self.startedAt)

        let glyph = row.phase.liveActivityGlyph(isStale: row.isStale)
        #expect(glyph.symbolName == row.symbol)
        #expect(glyph.badgeSymbolName == row.badge)
        #expect(row.phase.liveActivityAccent(isStale: row.isStale) == row.accent)
        #expect(row.phase.liveActivityFooter(isStale: row.isStale) == row.footer)
        let detail = state.liveActivityDetail(isStale: row.isStale)
        #expect(detail == (row.showsStart ? .started(Self.startedAt) : .checked(Self.checkedAt)))
    }
}
