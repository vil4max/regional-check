import AppIntents
import DriveCheckKit
import SwiftUI
import WidgetKit

struct DriveCheckStatusWidget: Widget {
    let kind = "DriveCheckStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DriveCheckStatusProvider()) { entry in
            DriveCheckStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.status.title")
        .description("widget.status.description")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct DriveCheckStatusProvider: TimelineProvider {
    func placeholder(in _: Context) -> DriveCheckStatusEntry {
        DriveCheckStatusEntry(
            date: Date(),
            presentation: WidgetStatusPresentation(
                phase: .idle,
                regionTitle: "Kyiv",
                checkedAt: nil,
                isStale: false
            )
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (DriveCheckStatusEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<DriveCheckStatusEntry>) -> Void) {
        let entry = makeEntry()
        let reload = WidgetTimelineBuilder.reloadDate(from: entry.date)
        completion(Timeline(entries: [entry], policy: .after(reload)))
    }

    private func makeEntry() -> DriveCheckStatusEntry {
        DriveCheckStatusEntry(
            date: Date(),
            presentation: WidgetTimelineBuilder.presentation(store: .shared)
        )
    }
}

struct DriveCheckStatusEntry: TimelineEntry {
    let date: Date
    let presentation: WidgetStatusPresentation
}

struct DriveCheckStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DriveCheckStatusEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        default:
            systemWidget
        }
    }

    private var accessoryCircular: some View {
        Image(systemName: entry.presentation.phase.symbolName)
            .widgetAccentable()
    }

    private var accessoryRectangular: some View {
        HStack {
            Image(systemName: entry.presentation.phase.symbolName)
            VStack(alignment: .leading) {
                Text(LocalizedStringKey(entry.presentation.phase.titleKey))
                    .font(.headline)
                Text(entry.presentation.regionTitle)
                    .font(.caption)
            }
        }
    }

    private var systemWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.presentation.phase.symbolName)
                    .font(.title2)
                Text(LocalizedStringKey(entry.presentation.phase.titleKey))
                    .font(.headline)
            }
            Text(entry.presentation.regionTitle)
                .font(.subheadline)
            if let checkedAt = entry.presentation.checkedAt {
                Text(checkedAt, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if entry.presentation.isStale {
                Text("liveActivity.stale")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let source = entry.presentation.sourceLabel, !source.isEmpty {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if #available(iOSApplicationExtension 17.0, *) {
                Button(intent: RefreshStatusIntent()) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}
