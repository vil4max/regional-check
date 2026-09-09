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
        DriveCheckSecondaryRegionWidget()
    }
}

struct DriveCheckLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveCheckActivityAttributes.self) { context in
            DriveCheckLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.92))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.phase.symbolName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DriveCheckLiveActivityStyle.accent(context.state.phase))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(LocalizedStringKey(context.state.phase.titleKey))
                            .font(.headline.weight(.semibold))
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
                    if context.isStale || context.state.isStale {
                        Text("liveActivity.stale")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbolName)
                    .foregroundStyle(DriveCheckLiveActivityStyle.accent(context.state.phase))
            } compactTrailing: {
                Text(LocalizedStringKey(context.isStale || context.state.isStale
                        ? "liveActivity.stale" : context.state.phase.titleKey))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            } minimal: {
                Image(systemName: context.state.phase.symbolName)
                    .foregroundStyle(DriveCheckLiveActivityStyle.accent(context.state.phase))
            }
        }
        .supplementalActivityFamilies([.small, .medium])
    }
}

private struct DriveCheckLockScreenView: View {
    let context: ActivityViewContext<DriveCheckActivityAttributes>
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: context.state.phase.symbolName)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(DriveCheckLiveActivityStyle.accent(context.state.phase))
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(context.isStale || context.state.isStale
                            ? "liveActivity.stale" : context.state.phase.titleKey))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
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
                    if !context.state.sourceLabel.isEmpty {
                        Text(context.state.sourceLabel)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    if context.isStale || context.state.isStale {
                        Text("liveActivity.stale")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(14)
    }
}

private enum DriveCheckLiveActivityStyle {
    static func accent(_ phase: DriveCheckActivityPhase) -> Color {
        switch phase {
        case .alarm:
            Color(red: 0.88, green: 0.48, blue: 0.48)
        case .quiet:
            Color(red: 0.35, green: 0.72, blue: 0.45)
        case .idle:
            Color(red: 0.55, green: 0.57, blue: 0.60)
        case .error:
            Color(red: 0.65, green: 0.55, blue: 0.35)
        }
    }
}
