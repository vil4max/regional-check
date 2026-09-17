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

    private var secondaryPresentation: WidgetStatusPresentation? {
        entry.secondaryPresentation
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
                if let secondaryPresentation {
                    dualTileMedium(secondary: secondaryPresentation)
                } else {
                    mediumWidget
                }
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

    /// RD-10 Behavior: "Medium (Pro): Current and Also watching tiles, refresh button (App
    /// Intent)." One `RefreshStatusIntent` covers both regions in a single fetch, so only the
    /// second tile carries the button.
    private func dualTileMedium(secondary secondaryPresentation: WidgetStatusPresentation) -> some View {
        HStack(spacing: 10) {
            tile(labelKey: "widget.status.currentLabel", presentation: presentation, showsRefresh: false)
            tile(labelKey: "widget.status.secondaryLabel", presentation: secondaryPresentation, showsRefresh: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tile(labelKey: String, presentation tilePresentation: WidgetStatusPresentation,
                      showsRefresh: Bool) -> some View {
        let tileIconColor = DriveCheckWidgetTokens.iconColor(
            phase: tilePresentation.phase,
            isStale: tilePresentation.isStale
        )
        let tileTitleColor = DriveCheckWidgetTokens.titleColor(
            phase: tilePresentation.phase,
            isStale: tilePresentation.isStale
        )
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(LocalizedStringKey(labelKey))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(secondary)
                Spacer(minLength: 4)
                if showsRefresh, presentation.phase != .idle {
                    refreshButton
                }
            }
            if tilePresentation.isStale {
                lastKnownCaption
            }
            Spacer(minLength: 0)
            Text(LocalizedStringKey(tilePresentation.titleKey))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(tileTitleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(tilePresentation.regionTitle)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(primary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            DriveCheckWidgetTokens.softTint(for: tileIconColor),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
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

    /// 44 pt is the minimum touch target (HIG), including the dual-tile's inline button — there
    /// is no room in a two-tile medium widget for a larger one.
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
