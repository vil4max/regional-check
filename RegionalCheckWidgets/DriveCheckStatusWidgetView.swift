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
            // One line, like the app's hero status (owner, 2026-09-21).
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .widgetAccentable()
            .layoutPriority(1)
    }

    /// The app's hero in miniature (owner, 2026-09-21: the widget should look at home on iOS 27):
    /// a ring of ticks and a tinted disc around the status glyph, all in the status colour.
    private func statusRing(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(
                    iconColor.opacity(0.38),
                    style: StrokeStyle(lineWidth: diameter * 0.05, dash: [1.5, diameter * 0.075])
                )
            Circle()
                .fill(iconColor.opacity(0.14))
                .overlay(Circle().strokeBorder(iconColor.opacity(0.40), lineWidth: 1))
                .padding(diameter * 0.16)
            statusIcon
                .font(.system(size: diameter * 0.34, weight: .semibold))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    private var regionRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.caption2)
            Text(presentation.regionTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.system(.subheadline, design: .rounded).weight(.medium))
        .foregroundStyle(primary)
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                statusRing(diameter: 52)
                Spacer(minLength: 4)
                // Nothing to refresh yet while the first fetch is in flight (row 9 "Checking…").
                if presentation.phase != .idle {
                    refreshButton
                }
            }
            Spacer(minLength: 0)
            if presentation.isStale {
                lastKnownCaption
            }
            statusTitle
            regionRow
            checkedAtLabel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            statusRing(diameter: 96)
            VStack(alignment: .leading, spacing: 4) {
                if presentation.isStale {
                    lastKnownCaption
                }
                statusTitle
                regionRow
                Spacer(minLength: 0)
                checkedAtLabel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            if presentation.phase != .idle {
                refreshButton
                    .frame(maxHeight: .infinity, alignment: .top)
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
