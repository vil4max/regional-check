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
    func placeholder(in _: Context) -> WidgetStatusTimelineEntry {
        WidgetStatusTimelineEntry(
            date: Date(),
            presentation: WidgetStatusPresentation(
                phase: .idle,
                regionTitle: AlertRegion.kyivCity.title,
                checkedAt: nil,
                isStale: false
            )
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (WidgetStatusTimelineEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<WidgetStatusTimelineEntry>) -> Void) {
        completion(WidgetTimelineBuilder.timeline(store: .shared))
    }

    private func makeEntry() -> WidgetStatusTimelineEntry {
        let now = Date()
        return WidgetStatusTimelineEntry(
            date: now,
            presentation: WidgetTimelineBuilder.presentation(store: .shared, now: now)
        )
    }
}
