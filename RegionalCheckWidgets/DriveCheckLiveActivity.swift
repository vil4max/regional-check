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
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveActivityRefreshButton
                }
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
                    }
                    .accessibilityElement(children: .combine)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
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
                LiveActivityGlyphView(presentation: presentation, font: .body)
                    .accessibilityHidden(false)
                    .accessibilityLabel(Text(LocalizedStringKey(presentation.titleKey)))
            } compactTrailing: {
                // Row 9 mockup: the region name, not the status word — the icon and its color
                // already carry the status in this tight a space. A long name ends in "…".
                Text(context.state.regionTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(presentation.iconColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } minimal: {
                // The symbol alone: no system format counts bare minutes without seconds, and the
                // circle has no room for "12 minutes" (REQ-SURF-014 clause 3, deviation recorded).
                LiveActivityGlyphView(presentation: presentation, font: .body)
                    .accessibilityHidden(false)
                    .accessibilityLabel(Text(LocalizedStringKey(presentation.titleKey)))
            }
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}
