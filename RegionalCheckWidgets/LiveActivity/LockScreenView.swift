import ActivityKit
import DriveCheckKit
import SwiftUI
import WidgetKit

/// The Live Activity outside the Dynamic Island: the Lock Screen, StandBy (full screen), and the
/// `.small` family that CarPlay's Dashboard and the Apple Watch Smart Stack draw (REQ-SURF-014).
/// The words and symbol are one VoiceOver element; the Refresh button stays its own.
struct DriveCheckLockScreenView: View {
    let context: ActivityViewContext<DriveCheckActivityAttributes>
    @Environment(\.activityFamily) private var activityFamily
    @Environment(\.isActivityFullscreen) private var isFullscreen

    var body: some View {
        let presentation = DriveCheckLiveActivityPresentation(context: context)
        if activityFamily == .small {
            SmallActivityView(presentation: presentation, regionTitle: context.state.regionTitle)
        } else if isFullscreen {
            StandByActivityView(presentation: presentation, regionTitle: context.state.regionTitle)
        } else {
            RegularActivityView(presentation: presentation, regionTitle: context.state.regionTitle)
        }
    }
}

private struct RegularActivityView: View {
    let presentation: DriveCheckLiveActivityPresentation
    let regionTitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                LiveActivityGlyphView(presentation: presentation, font: .title.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(presentation.titleKey))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(presentation.titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(regionTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    detailRow
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            // Unlike the widget, also while checking: an activity left at "Checking…" in the
            // background has no other way to recover without opening the app.
            liveActivityRefreshButton
        }
        .padding(14)
    }

    @ViewBuilder
    private var detailRow: some View {
        HStack(spacing: 6) {
            LiveActivityDetailLine(detail: presentation.detail)
            // A running duration also keeps the check time, which tells how fresh the red is.
            if case .started = presentation.detail, let checkedAt = presentation.checkedAt {
                Text(checkedAt, style: .time)
                    .monospacedDigit()
            }
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.72))
        if let footer = presentation.footer {
            Text(verbatim: footer)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

/// CarPlay disables buttons (Apple, Displaying live data), so the `.small` view has none; nothing
/// here is smaller than the caption style, readable at 240×78 and 170×78 pt (spec AC-1).
private struct SmallActivityView: View {
    let presentation: DriveCheckLiveActivityPresentation
    let regionTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                LiveActivityGlyphView(presentation: presentation, font: .headline.weight(.semibold))
                Text(LocalizedStringKey(presentation.titleKey))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(presentation.titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(regionTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            // The Watch must not show a stale alarm as fresh either (REQ-SURF-003): its footer
            // replaces the line, since a stale alarm shows no duration.
            if presentation.footerKind == .mayBeOutdated, let footer = presentation.footer {
                Text(verbatim: footer)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                LiveActivityDetailLine(detail: presentation.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// StandBy shows the activity full screen on a phone across the room: the state and the region
/// large enough to read from there (spec AC-7).
private struct StandByActivityView: View {
    let presentation: DriveCheckLiveActivityPresentation
    let regionTitle: String

    var body: some View {
        HStack(spacing: 20) {
            LiveActivityGlyphView(presentation: presentation, font: .system(size: 56, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(presentation.titleKey))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(presentation.titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(regionTitle)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                LiveActivityDetailLine(detail: presentation.detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if let footer = presentation.footer {
                    Text(verbatim: footer)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .padding(20)
    }
}
