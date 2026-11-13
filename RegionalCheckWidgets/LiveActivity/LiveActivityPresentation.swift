import ActivityKit
import DriveCheckKit
import SwiftUI
import WidgetKit

/// Row 9 ("Live Activity, Dynamic Island, Home Screen widget: stale and checking"): the words and
/// glyphs come from `StatusPresentation.liveActivity`; this adds the colours. A stale alarm never
/// downgrades (REQ-REFRESH-009), and its footer says it may be outdated instead (REQ-SURF-003).
struct DriveCheckLiveActivityPresentation {
    let titleKey: String
    let titleColor: Color
    /// ALERT-push AC-10: a shape per state, so the states differ without colour.
    let iconName: String
    let badgeName: String?
    let iconColor: Color
    /// The Lock Screen/expanded footer line, decided by `liveActivityFooter(isStale:)`.
    let footerKind: LiveActivityFooter?
    /// Already localized (one of them is formatted), so it is drawn with `Text(verbatim:)`.
    let footer: String?
    /// REQ-SURF-014: how long ago a fresh alarm started, else the check time.
    let detail: LiveActivityDetail
    /// REQ-SURF-014 clause 4: what VoiceOver says for a one-symbol presentation.
    let spokenParts: [LiveActivitySpokenPart]
    /// The time of the data, the response's own, and its "Updated: 08:54" line. Shown in every state
    /// that has one: the driver's way to judge freshness (owner, 2026-11-13).
    let updatedAt: Date?
    let updatedText: String?

    init(context: ActivityViewContext<DriveCheckActivityAttributes>) {
        self.init(state: context.state, systemIsStale: context.isStale)
    }

    init(state: DriveCheckActivityAttributes.ContentState, systemIsStale: Bool) {
        let phase = state.phase
        let isStale = systemIsStale || state.isStale
        let accent = phase.liveActivityAccent(isStale: isStale)
        let status = StatusPresentation.liveActivity(phase: phase, isStale: isStale)
        iconColor = DriveCheckWidgetTokens.iconColor(accent: accent)
        titleKey = status.compactTitleKey
        let glyph = phase.liveActivityGlyph(isStale: isStale)
        iconName = glyph.symbolName
        badgeName = glyph.badgeSymbolName
        detail = state.liveActivityDetail(isStale: isStale)
        spokenParts = state.liveActivitySpokenParts(isStale: isStale)
        updatedAt = state.liveActivityUpdatedAt
        updatedText = state.liveActivityUpdatedAt.map {
            String(format: String(localized: "Updated: %@"), $0.formatted(date: .omitted, time: .shortened))
        }

        switch accent {
        case .checking where phase == .idle:
            titleColor = DriveCheckWidgetTokens.textPrimary
        case .stale:
            // Like the widget: the glyph carries the grey, the words stay plain.
            titleColor = DriveCheckWidgetTokens.titleColor(accent: accent)
        default:
            titleColor = iconColor
        }

        footerKind = phase.liveActivityFooter(isStale: isStale)
        switch footerKind {
        case .checking:
            footer = String(localized: "liveActivity.checkingFooter")
        case .mayBeOutdated:
            footer = String(localized: "liveActivity.mayBeOutdatedFooter")
        case nil:
            footer = nil
        }
    }
}

extension DriveCheckLiveActivityPresentation {
    /// What VoiceOver says for a presentation that is one symbol (compact, minimal), built from
    /// `spokenParts` (REQ-SURF-014 clause 4), comma-separated.
    func spokenSummary(regionTitle: String) -> Text {
        var sentence: Text?
        for part in spokenParts {
            let text: Text
            switch part {
            case .state:
                text = Text(LocalizedStringKey(titleKey))
            case .region:
                text = Text(verbatim: regionTitle)
            case .started(let start):
                let elapsed = Text(.currentDate, format: .reference(to: start, allowedFields: [.hour, .minute]))
                text = Text("liveActivity.started \(elapsed)")
            case .updated:
                text = Text(verbatim: updatedText ?? "")
            case .footer:
                text = Text(verbatim: footer ?? "")
            }
            sentence = sentence.map { $0 + Text(verbatim: ", ") + text } ?? text
        }
        return sentence ?? Text(verbatim: regionTitle)
    }
}

/// The state's symbol with its optional badge at the bottom trailing corner (ALERT-push AC-10).
struct LiveActivityGlyphView: View {
    let presentation: DriveCheckLiveActivityPresentation
    let font: Font

    var body: some View {
        Image(systemName: presentation.iconName)
            .font(font)
            .foregroundStyle(presentation.iconColor)
            .overlay(alignment: .bottomTrailing) {
                if let badge = presentation.badgeName {
                    Image(systemName: badge)
                        .font(font)
                        .imageScale(.small)
                        .scaleEffect(0.6)
                        .foregroundStyle(DriveCheckWidgetTokens.iconColor(accent: .stale))
                        .offset(x: 4, y: 4)
                        .accessibilityHidden(true)
                }
            }
        // Not hidden here: compact and minimal make this symbol their one VoiceOver element. Where
        // words beside it already say the state, the caller hides it.
    }
}

/// REQ-SURF-014: "Started 12 minutes ago" for a fresh alarm whose start the feed gives (the system
/// advances it without pushes, minutes and hours only), then "Updated: 08:54", the time of the
/// data, in every state that has one. Each line may wrap rather than lose its end. The caller sets
/// the font and colour.
struct LiveActivityTimeLines: View {
    let presentation: DriveCheckLiveActivityPresentation
    var alignment: HorizontalAlignment = .leading
    var showsUpdated = true

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            switch presentation.detail {
            case .started(let start):
                let elapsed = Text(.currentDate, format: .reference(to: start, allowedFields: [.hour, .minute]))
                Text("liveActivity.started \(elapsed)")
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                updatedLine
            case .checked, .none:
                updatedLine
            }
        }
    }

    @ViewBuilder
    private var updatedLine: some View {
        if showsUpdated, let updatedText = presentation.updatedText {
            Text(verbatim: updatedText)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

/// REQ-SURF-009: re-checks the region in the app process without opening the app, and ends the
/// activity on a confirmed all-clear.
@MainActor
var liveActivityRefreshButton: some View {
    StatusRefreshButton(intent: RefreshLiveActivityIntent(), color: DriveCheckWidgetTokens.textPrimary)
}
