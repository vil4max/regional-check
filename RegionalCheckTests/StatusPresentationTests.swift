import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The one status word and glyph mapping every surface reads (`StatusPresentation`), as a table.
@MainActor
struct StatusPresentationTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let phase: StatusPresentation.Phase
        let isStale: Bool
        let titleKey: String
        let symbolName: String

        init(_ phase: StatusPresentation.Phase, stale: Bool, _ titleKey: String, _ symbolName: String) {
            self.phase = phase
            self.isStale = stale
            self.titleKey = titleKey
            self.symbolName = symbolName
        }

        var testDescription: String {
            "\(phase) stale=\(isStale)"
        }
    }

    private nonisolated static let check = "checkmark.shield.fill"
    private nonisolated static let alarm = "light.beacon.max.fill"
    private nonisolated static let sync = "arrow.triangle.2.circlepath"
    private nonisolated static let question = "questionmark.circle.fill"
    private nonisolated static let clock = "clock.fill"

    nonisolated static let table: [Row] = [
        Row(.quiet, stale: false, "All Clear", check),
        Row(.quiet, stale: true, "All Clear", clock),
        Row(.alarm, stale: false, "Alert Active", alarm),
        Row(.alarm, stale: true, "Alert Active", alarm),
        Row(.idle, stale: false, "Checking…", sync),
        Row(.idle, stale: true, "Checking…", clock),
        Row(.error, stale: false, "Unavailable", question),
        Row(.error, stale: true, "Unavailable", clock),
        Row(.regionUnavailable, stale: false, "Region Unavailable", question),
        Row(.regionUnavailable, stale: true, "Region Unavailable", clock),
    ]

    @Test(
        "REQ-REFRESH-009 STATUS-two-states AC-5 one title key and glyph per phase and staleness",
        arguments: table)
    func mappingTable(_ row: Row) {
        let presentation = StatusPresentation(phase: row.phase, isStale: row.isStale)
        #expect(presentation.titleKey == row.titleKey)
        #expect(presentation.symbolName == row.symbolName)
    }

    @Test("The phone's status words use the shared title keys")
    func phoneTitlesUseTheSharedKeys() {
        let date = Date(timeIntervalSince1970: 1000)
        let states: [StatusState] = [
            .idle, .quiet(lastCheckedAt: date), .alarm(lastCheckedAt: date), .error, .regionUnavailable,
        ]
        for state in states {
            let key = StatusPresentation.titleKey(for: state.phase.presentationPhase)
            #expect(state.title == String(localized: String.LocalizationValue(key)))
            #expect(state.symbolName == StatusPresentation.symbolName(for: state.phase.presentationPhase))
        }
    }

    @Test("REQ-LAUNCH-004 the hero and the cold-start overlay draw the shared glyph for every accent")
    func heroSymbolPerAccent() {
        let expected: [Theme.RedesignStatusAccent: String] = [
            .clear: Self.check,
            .alert: Self.alarm,
            .stale: Self.clock,
            .checking: Self.sync,
            .unavailable: Self.question,
        ]
        for accent in Theme.RedesignStatusAccent.allCases {
            #expect(accent.symbolName == expected[accent])
            #expect(Theme.RedesignStatusAccent(accent.representativePresentation) == accent)
        }
        for row in Self.table {
            let presentation = StatusPresentation(phase: row.phase, isStale: row.isStale)
            #expect(Theme.RedesignStatusAccent(presentation).symbolName == presentation.symbolName)
        }
    }

    @Test("REQ-SURF-003 the Live Activity: checking wins, old non-alarm data reads No Current Data")
    func liveActivityWording() {
        let idle = StatusPresentation.liveActivity(phase: .idle, isStale: true)
        #expect(idle.compactTitleKey == "Checking…")
        #expect(idle.symbolName == Self.sync)

        let staleQuiet = StatusPresentation.liveActivity(phase: .quiet, isStale: true)
        #expect(staleQuiet.compactTitleKey == "widget.status.noCurrentData")
        #expect(staleQuiet.symbolName == Self.clock)

        let staleAlarm = StatusPresentation.liveActivity(phase: .alarm, isStale: true)
        #expect(staleAlarm.compactTitleKey == "Alert Active")
        #expect(staleAlarm.symbolName == Self.alarm)

        let error = StatusPresentation.liveActivity(phase: .error, isStale: false)
        #expect(error.compactTitleKey == "Unavailable")
    }

    @Test("The widget's missing region reads Region Unavailable, as Siri says it")
    func widgetMissingRegion() {
        let widget = WidgetStatusPresentation(phase: .error, regionTitle: "Kyiv", checkedAt: nil)
        #expect(widget.status.phase == .regionUnavailable)
        #expect(widget.titleKey == "Region Unavailable")
        #expect(widget.glyphName == Self.question)
    }
}
