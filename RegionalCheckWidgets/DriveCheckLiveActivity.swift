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

/// The Live Activity everywhere it shows (REQ-SURF-014). The Lock Screen, StandBy and the `.small`
/// family (CarPlay Dashboard, Apple Watch) are `DriveCheckLockScreenView`; the Dynamic Island is
/// here. The shared pieces live in `LiveActivity/`.
struct DriveCheckLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveCheckActivityAttributes.self) { context in
            DriveCheckLockScreenView(context: context)
                .activityBackgroundTint(DriveCheckWidgetTokens.background.opacity(0.92))
        } dynamicIsland: { context in
            let presentation = DriveCheckLiveActivityPresentation(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityGlyphView(presentation: presentation, font: .title2.weight(.semibold))
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveActivityRefreshButton
                }
                // State, region, detail and footer sit in one region so VoiceOver reads them as one
                // element (REQ-SURF-014 clause 4); the bottom region stays empty.
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey(presentation.titleKey))
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(presentation.titleColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(context.state.regionTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        LiveActivityDetailLine(detail: presentation.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let footer = presentation.footer {
                            Text(verbatim: footer)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    // A self-updating date text takes the full width, so its own alignment centres it.
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            } compactLeading: {
                // Compact leading and trailing are separate regions: the leading one speaks for both,
                // and the trailing region name is hidden from VoiceOver.
                LiveActivityGlyphView(presentation: presentation, font: .body)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(presentation.spokenSummary(regionTitle: context.state.regionTitle))
            } compactTrailing: {
                // Row 9 mockup: the region name, not the status word — the icon and its color
                // already carry the status in this tight a space. A long name ends in "…".
                Text(context.state.regionTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(presentation.iconColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityHidden(true)
            } minimal: {
                // The symbol alone for now: no system format counts bare minutes without seconds,
                // and the circle has no room for "12 minutes". REQ-SURF-014 clause 3 is open with the
                // owner (plan point 8).
                LiveActivityGlyphView(presentation: presentation, font: .body)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(presentation.spokenSummary(regionTitle: context.state.regionTitle))
            }
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}
