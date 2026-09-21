import AppIntents
import DriveCheckKit
import SwiftUI
import WidgetKit

struct DriveCheckStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: DriveCheckStatusEntry

    private var presentation: WidgetStatusPresentation {
        entry.presentation
    }

    private var iconColor: Color {
        let full = DriveCheckWidgetTokens.iconColor(phase: presentation.phase, isStale: presentation.isStale)
        return renderingMode == .fullColor ? full : .primary
    }

    private var titleColor: Color {
        let full = DriveCheckWidgetTokens.titleColor(phase: presentation.phase, isStale: presentation.isStale)
        return renderingMode == .fullColor ? full : .primary
    }

    private var primary: Color {
        renderingMode == .fullColor ? DriveCheckWidgetTokens.textPrimary.opacity(0.92) : .primary
    }

    private var secondary: Color {
        renderingMode == .fullColor ? DriveCheckWidgetTokens.textSecondary : .secondary
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                statusIcon
                    .accessibilityLabel(Text(LocalizedStringKey(presentation.titleKey)))
                    .accessibilityValue(Text(presentation.regionTitle))
            case .accessoryRectangular:
                accessoryRectangular
            case .systemMedium:
                mediumWidget
            default:
                smallWidget
            }
        }
        .containerBackground(for: .widget) {
            if family == .systemSmall || family == .systemMedium {
                DriveCheckWidgetTokens.background(accent: iconColor)
            }
        }
    }

    private var statusIcon: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
            .widgetAccentable()
    }

    private var iconName: String {
        DriveCheckWidgetTokens.iconName(
            phase: presentation.phase,
            isStale: presentation.isStale,
            normal: presentation.symbolName
        )
    }

    private var lastKnownCaption: some View {
        Text("widget.status.lastKnownLabel")
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(DriveCheckWidgetTokens.statusStale)
    }

    private var statusTitle: some View {
        Text(LocalizedStringKey(presentation.titleKey))
            .font(.system(family == .systemMedium ? .title2 : .headline, design: .rounded).weight(.bold))
            .foregroundStyle(titleColor)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .widgetAccentable()
            .layoutPriority(1)
    }

    private var regionTitle: some View {
        Text(presentation.regionTitle)
            .font(.system(.subheadline, design: .rounded).weight(.medium))
            .foregroundStyle(primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                statusIcon
                    .font(.system(size: 28, weight: .semibold))
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                // Nothing to refresh yet while the first fetch is in flight (row 9 "Checking…").
                if presentation.phase != .idle {
                    refreshButton
                }
            }
            if presentation.isStale {
                lastKnownCaption
            }
            statusTitle
            regionTitle
            Spacer(minLength: 0)
            checkedAtLabel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumWidget: some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon
                .font(.system(size: 34, weight: .semibold))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                regionTitle
                if presentation.isStale {
                    lastKnownCaption
                }
                statusTitle
                Spacer(minLength: 0)
                checkedAtLabel
                if let source = presentation.sourceLabel, !source.isEmpty {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if presentation.phase != .idle {
                refreshButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 6) {
            statusIcon
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                statusTitle
                Text(presentation.regionTitle)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var checkedAtLabel: some View {
        if let checkedAt = presentation.checkedAt {
            let includesDate = !Calendar.current.isDate(checkedAt, inSameDayAs: entry.date)
            let formatted = checkedAt.formatted(date: includesDate ? .abbreviated : .omitted, time: .shortened)
            // REQ-REFRESH-009: keeps the real status visible, marks the time with a warning.
            let prefix = presentation.isStale ? "⚠ " : ""
            Text(prefix + String(format: String(localized: "Updated: %@"), formatted))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// 44 pt is the minimum touch target (HIG).
    private var refreshButton: some View {
        Button(intent: RefreshStatusIntent()) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .foregroundStyle(primary)
                .frame(width: 36, height: 36)
                .background(primary.opacity(0.10), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
