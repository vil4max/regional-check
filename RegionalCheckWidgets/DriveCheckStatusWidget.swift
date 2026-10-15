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
            .accessoryRectangular,
        ])
    }
}

extension WidgetStatusTimelineEntry {
    /// Representative data for the widget gallery, where an empty store would otherwise render
    /// the idle "Checking…" state as if that were what the widget looks like.
    static func previewSample(now: Date = Date()) -> WidgetStatusTimelineEntry {
        WidgetStatusTimelineEntry(
            date: now,
            presentation: WidgetStatusPresentation(
                phase: .quiet,
                regionTitle: AlertRegion.kyivCity.title,
                checkedAt: now
            )
        )
    }
}

struct DriveCheckStatusProvider: TimelineProvider {
    func placeholder(in _: Context) -> WidgetStatusTimelineEntry {
        .previewSample()
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetStatusTimelineEntry) -> Void) {
        let entry = makeEntry(now: Date(), store: .shared)
        // Real data wins when the store has any; only the empty-store idle state is replaced.
        if context.isPreview, entry.presentation.phase == .idle {
            completion(.previewSample())
            return
        }
        completion(entry)
    }

    /// `@Sendable` matches the `TimelineProvider` requirement, which WidgetKit declares
    /// `@preconcurrency`. Swift 5 mode tolerated the weaker witness; Swift 6 mode does not,
    /// because the refresh below hands `completion` to a `Task`.
    func getTimeline(
        in _: Context,
        completion: @escaping @Sendable (Timeline<WidgetStatusTimelineEntry>) -> Void
    ) {
        Task {
            // Polling loop: try to refresh, keep last-known-good on failure,
            // then return a timeline whose .after policy schedules the next poll.
            await WidgetTimelineRefresh.refresh(store: .shared)
            completion(WidgetTimelineBuilder.timeline(store: .shared, now: Date()))
        }
    }

    private func makeEntry(now: Date, store: SharedStore) -> WidgetStatusTimelineEntry {
        WidgetStatusTimelineEntry(
            date: now,
            presentation: WidgetTimelineBuilder.presentation(store: store, now: now)
        )
    }
}
