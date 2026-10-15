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
        let isSurrounded: Bool
        let titleKey: String
        let symbolName: String
        let isCaution: Bool

        init(
            _ phase: StatusPresentation.Phase,
            stale: Bool,
            surrounded: Bool,
            _ titleKey: String,
            _ symbolName: String,
            caution: Bool = false
        ) {
            self.phase = phase
            self.isStale = stale
            self.isSurrounded = surrounded
            self.titleKey = titleKey
            self.symbolName = symbolName
            self.isCaution = caution
        }

        var testDescription: String {
            "\(phase) stale=\(isStale) surrounded=\(isSurrounded)"
        }
    }

    private nonisolated static let check = "checkmark.circle.fill"
    private nonisolated static let alarm = "exclamationmark.circle.fill"
    private nonisolated static let triangle = "exclamationmark.triangle.fill"
    private nonisolated static let sync = "arrow.triangle.2.circlepath"
    private nonisolated static let question = "questionmark.circle.fill"
    private nonisolated static let clock = "clock.fill"

    nonisolated static let table: [Row] = [
        Row(.quiet, stale: false, surrounded: false, "All Clear", check),
        Row(.quiet, stale: false, surrounded: true, "status.caution.title", triangle, caution: true),
        Row(.quiet, stale: true, surrounded: false, "All Clear", clock),
        Row(.quiet, stale: true, surrounded: true, "All Clear", clock),
        Row(.alarm, stale: false, surrounded: false, "Alert Active", alarm),
        Row(.alarm, stale: false, surrounded: true, "Alert Active", alarm),
        Row(.alarm, stale: true, surrounded: true, "Alert Active", alarm),
        Row(.idle, stale: false, surrounded: false, "Checking…", sync),
        Row(.idle, stale: true, surrounded: false, "Checking…", clock),
        Row(.error, stale: false, surrounded: true, "Unavailable", question),
        Row(.error, stale: true, surrounded: false, "Unavailable", clock),
        Row(.regionUnavailable, stale: false, surrounded: false, "Region Unavailable", question),
        Row(.regionUnavailable, stale: true, surrounded: false, "Region Unavailable", clock),
    ]

    @Test(
        "REQ-SURF-010 REQ-REFRESH-009 one title key, glyph and caution flag per phase, staleness and surround",
        arguments: table)
    func mappingTable(_ row: Row) {
        let presentation = StatusPresentation(phase: row.phase, isStale: row.isStale, isSurrounded: row.isSurrounded)
        #expect(presentation.titleKey == row.titleKey)
        #expect(presentation.symbolName == row.symbolName)
        #expect(presentation.isCaution == row.isCaution)
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
            .caution: Self.triangle,
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
            let presentation = StatusPresentation(
                phase: row.phase, isStale: row.isStale, isSurrounded: row.isSurrounded
            )
            #expect(Theme.RedesignStatusAccent(presentation).symbolName == presentation.symbolName)
        }
    }

    @Test("REQ-SURF-010 the controller derives the Status accent once from its own data")
    func controllerAccent() async {
        let app = AppContainer.fixture(
            region: .kyivCity,
            network: FixtureNetwork(alarmRegions: [.kyivOblast, .chernihiv, .zhytomyr]),
            defaultsSuite: "RegionalCheckTests.presentation.\(UUID().uuidString)"
        )
        await app.status.refresh()
        // The fixture's clock is fixed at the snapshot's time, so the data is fresh.
        #expect(app.status.state.phase == .quiet)
        #expect(!app.status.isDataStale)
        #expect(app.status.presentation.isCaution)
        #expect(app.status.presentation.symbolName == StatusPresentation.cautionSymbolName)
        #expect(app.status.accent == .caution)
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
        #expect(!StatusPresentation.liveActivity(phase: .quiet, isStale: false).isCaution)
    }

    @Test("The widget's missing region reads Region Unavailable, as Siri says it")
    func widgetMissingRegion() {
        let widget = WidgetStatusPresentation(phase: .error, regionTitle: "Kyiv", checkedAt: nil)
        #expect(widget.status.phase == .regionUnavailable)
        #expect(widget.titleKey == "Region Unavailable")
        #expect(widget.glyphName == Self.question)
    }
}
