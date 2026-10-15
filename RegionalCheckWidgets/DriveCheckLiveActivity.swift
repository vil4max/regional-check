import ActivityKit
import DriveCheckKit
import SwiftUI
import WidgetKit

@main
struct RegionalCheckWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DriveCheckLiveActivity()
        DriveCheckStatusWidget()
        DriveCheckStatusControl()
    }
}

struct DriveCheckLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveCheckActivityAttributes.self) { context in
            DriveCheckLockScreenView(context: context)
                .activityBackgroundTint(DriveCheckWidgetTokens.background.opacity(0.92))
        } dynamicIsland: { context in
            let presentation = DriveCheckLiveActivityPresentation(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: presentation.iconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(presentation.iconColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveActivityRefreshButton
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey(presentation.titleKey))
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(presentation.titleColor)
                        Text(context.state.regionTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let checkedAt = context.state.checkedAt {
                        Text(checkedAt, style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let footer = presentation.footer {
                        Text(verbatim: footer)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: presentation.iconName)
                    .foregroundStyle(presentation.iconColor)
            } compactTrailing: {
                // Row 9 mockup: the region name, not the status word — the icon and its color
                // already carry the status in this tight a space.
                Text(context.state.regionTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(presentation.iconColor)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: presentation.iconName)
                    .foregroundStyle(presentation.iconColor)
            }
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}

private struct DriveCheckLockScreenView: View {
    let context: ActivityViewContext<DriveCheckActivityAttributes>
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        let presentation = DriveCheckLiveActivityPresentation(context: context)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: presentation.iconName)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(presentation.iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(presentation.titleKey))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(presentation.titleColor)
                    Text(context.state.regionTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                // Unlike the widget, also while checking: an activity left at "Checking…" in the
                // background has no other way to recover without opening the app.
                if activityFamily != .small {
                    liveActivityRefreshButton
                }
            }
            if activityFamily == .small {
                if let checkedAt = context.state.checkedAt {
                    Text(checkedAt, style: .time)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                // The small family is what the Apple Watch Smart Stack shows; a stale alarm must
                // not look fresh there either (REQ-SURF-003).
                if presentation.footerKind == .mayBeOutdated, let footer = presentation.footer {
                    Text(verbatim: footer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            if activityFamily != .small {
                HStack {
                    if let checkedAt = context.state.checkedAt {
                        Text(checkedAt, style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    if let footer = presentation.footer {
                        Text(verbatim: footer)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(14)
    }
}

/// REQ-SURF-009: re-checks the region in the app process without opening the app, and ends the
/// activity on a confirmed all-clear.
@MainActor
private var liveActivityRefreshButton: some View {
    StatusRefreshButton(intent: RefreshLiveActivityIntent(), color: DriveCheckWidgetTokens.textPrimary)
}

/// Row 9 ("Live Activity, Dynamic Island, Home Screen widget: stale and checking"): the words and
/// glyphs come from `StatusPresentation.liveActivity`; this adds the colours. A stale alarm never
/// downgrades (REQ-REFRESH-009), and its footer says it may be outdated instead (REQ-SURF-003).
private struct DriveCheckLiveActivityPresentation {
    let titleKey: String
    let titleColor: Color
    let iconName: String
    let iconColor: Color
    /// The Lock Screen/expanded footer line, decided by `liveActivityFooter(isStale:)`.
    let footerKind: LiveActivityFooter?
    /// Already localized (one of them is formatted), so it is drawn with `Text(verbatim:)`.
    let footer: String?

    init(context: ActivityViewContext<DriveCheckActivityAttributes>) {
        let phase = context.state.phase
        let isStale = context.isStale || context.state.isStale
        let accent = phase.liveActivityAccent(isStale: isStale)
        let status = StatusPresentation.liveActivity(phase: phase, isStale: isStale)
        iconColor = DriveCheckWidgetTokens.iconColor(accent: accent)
        titleKey = status.compactTitleKey
        iconName = status.symbolName

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

private extension DriveCheckActivityPhase {
    /// The Live Activity extension's own bundle localizes `titleKey`'s raw catalog key; this
    /// resolves it to plain text for interpolation into `liveActivity.staleFooter`'s `%@`.
    var titleKeyText: String {
        String(localized: String.LocalizationValue(titleKey))
    }
}
