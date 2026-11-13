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
    let checkedAt: Date?

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
        checkedAt = state.checkedAt

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
        case .lastKnown:
            footer = String(format: String(localized: "liveActivity.staleFooter"), phase.titleKeyText)
        case .mayBeOutdated:
            footer = String(localized: "liveActivity.mayBeOutdatedFooter")
        case nil:
            footer = nil
        }
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
            .accessibilityHidden(true)
    }
}

/// REQ-SURF-014: "Started 12 minutes ago", which the system advances without pushes (minutes and
/// hours only, no seconds), or the check time. The caller sets the font and colour.
struct LiveActivityDetailLine: View {
    let detail: LiveActivityDetail

    var body: some View {
        switch detail {
        case .started(let start):
            let elapsed = Text(.currentDate, format: .reference(to: start, allowedFields: [.hour, .minute]))
            Text("liveActivity.started \(elapsed)")
        case .checked(let checkedAt):
            Text(checkedAt, style: .time)
                .monospacedDigit()
        case .none:
            EmptyView()
        }
    }
}

/// REQ-SURF-009: re-checks the region in the app process without opening the app, and ends the
/// activity on a confirmed all-clear.
@MainActor
var liveActivityRefreshButton: some View {
    StatusRefreshButton(intent: RefreshLiveActivityIntent(), color: DriveCheckWidgetTokens.textPrimary)
}

private extension DriveCheckActivityPhase {
    /// The Live Activity extension's own bundle localizes `titleKey`'s raw catalog key; this
    /// resolves it to plain text for interpolation into `liveActivity.staleFooter`'s `%@`.
    var titleKeyText: String {
        String(localized: String.LocalizationValue(titleKey))
    }
}
