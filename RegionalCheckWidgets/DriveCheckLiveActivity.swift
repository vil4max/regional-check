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
                        Text(footer)
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

    private var presentation: DriveCheckLiveActivityPresentation {
        DriveCheckLiveActivityPresentation(context: context)
    }

    var body: some View {
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
            }
            if activityFamily == .small, let checkedAt = context.state.checkedAt {
                Text(checkedAt, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if activityFamily != .small {
                HStack {
                    if let checkedAt = context.state.checkedAt {
                        Text(checkedAt, style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    if let footer = presentation.footer {
                        Text(footer)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(14)
    }
}

/// Row 9 ("Live Activity, Dynamic Island, Home Screen widget: stale and checking"): the Live
/// Activity has three cases, checked in order — checking always wins (it means "no data yet",
/// not "old data"); a stale non-alarm status downgrades its title to "No Current Data" per the
/// mockup, since the Lock Screen has no room for a "Last known" qualifier next to the title; a
/// stale alarm never downgrades (REQ-REFRESH-009: "a known alarm stays red... never replaced"),
/// and its footer says it may be outdated instead (REQ-SURF-003).
private struct DriveCheckLiveActivityPresentation {
    let titleKey: String
    let titleColor: Color
    let iconName: String
    let iconColor: Color
    /// The Lock Screen/expanded footer line, decided by `liveActivityFooter(isStale:)`.
    let footer: LocalizedStringKey?

    init(context: ActivityViewContext<DriveCheckActivityAttributes>) {
        let phase = context.state.phase
        let isStale = context.isStale || context.state.isStale
        let accent = phase.liveActivityAccent(isStale: isStale)
        iconColor = DriveCheckWidgetTokens.iconColor(accent: accent)

        switch accent {
        case .checking where phase == .idle:
            titleKey = phase.titleKey
            titleColor = DriveCheckWidgetTokens.textPrimary
            iconName = phase.symbolName
        case .stale:
            // Like the widget: the glyph carries the grey, the words stay plain.
            titleKey = "widget.status.noCurrentData"
            titleColor = DriveCheckWidgetTokens.titleColor(accent: accent)
            iconName = "clock.fill"
        default:
            titleKey = phase.titleKey
            titleColor = iconColor
            iconName = phase.symbolName
        }

        switch phase.liveActivityFooter(isStale: isStale) {
        case .checking:
            footer = LocalizedStringKey("liveActivity.checkingFooter")
        case .lastKnown:
            footer = LocalizedStringKey(String(
                format: String(localized: "liveActivity.staleFooter"),
                phase.titleKeyText
            ))
        case .mayBeOutdated:
            footer = LocalizedStringKey("liveActivity.mayBeOutdatedFooter")
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
