import AppIntents
import DriveCheckKit
import SwiftUI
import WidgetKit

struct DriveCheckStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: WidgetStatusTimelineEntry

    private var presentation: WidgetStatusPresentation {
        entry.presentation
    }

    private var accent: Color {
        DriveCheckWidgetStyle.accent(for: presentation)
    }

    private var primary: Color {
        renderingMode == .fullColor ? .white.opacity(0.92) : .primary
    }

    private var secondary: Color {
        renderingMode == .fullColor ? .white.opacity(0.72) : .secondary
    }

    private var statusColor: Color {
        renderingMode == .fullColor ? accent : .primary
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
                DriveCheckWidgetStyle.background(accent: accent)
            }
        }
    }

    private var statusIcon: some View {
        Image(systemName: presentation.symbolName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(statusColor)
            .widgetAccentable()
    }

    private var statusTitle: some View {
        Text(LocalizedStringKey(presentation.titleKey))
            .font(.system(family == .systemMedium ? .title2 : .headline, design: .rounded).weight(.bold))
            .foregroundStyle(statusColor)
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
                refreshButton
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
            refreshButton
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
            // Last-known-good + age: stale data keeps its status, only the
            // timestamp gains a warning marker.
            let prefix = presentation.isStale ? "⚠ " : ""
            Text(prefix + String(format: String(localized: "Updated: %@"), formatted))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

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

enum DriveCheckWidgetStyle {
    // Match the app's Theme.Colors across the separate extension target.
    static let normal = Color(red: 0.45, green: 0.62, blue: 0.52)
    static let attention = Color(red: 0.88, green: 0.48, blue: 0.48)
    static let staleData = Color(red: 0.90, green: 0.72, blue: 0.38)
    static let unavailable = Color(red: 0.52, green: 0.54, blue: 0.58)
    static let dashboard = Color(red: 0.07, green: 0.08, blue: 0.10)

    static func accent(for presentation: WidgetStatusPresentation) -> Color {
        // Never hide a known alarm behind grey: expired means "data is old",
        // not "status unknown". Alarm stays red at any freshness.
        switch presentation.phase {
        case .alarm:
            attention
        case .quiet:
            presentation.freshness == .fresh ? normal : staleData
        case .idle, .error:
            unavailable
        }
    }

    static func background(accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [dashboard, dashboard.mix(with: accent, by: 0.12, in: .device)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
