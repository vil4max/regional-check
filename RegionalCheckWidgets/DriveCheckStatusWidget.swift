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

/// RD-10 (Behavior: "Medium (Pro): Current and Also watching tiles"): the medium family needs
/// both the primary region and the Pro secondary region in one entry, so this wraps
/// `WidgetStatusTimelineEntry` with an optional second presentation instead of changing the
/// shared `DriveCheckKit` entry type other providers rely on.
struct DriveCheckStatusEntry: TimelineEntry {
    let date: Date
    let presentation: WidgetStatusPresentation
    let secondaryPresentation: WidgetStatusPresentation?

    /// Representative data for the widget gallery, where an empty store would otherwise render
    /// the idle "Checking…" state as if that were what the widget looks like.
    static func previewSample(now: Date = Date()) -> DriveCheckStatusEntry {
        DriveCheckStatusEntry(
            date: now,
            presentation: WidgetStatusPresentation(
                phase: .quiet,
                regionTitle: AlertRegion.kyivCity.title,
                checkedAt: now
            ),
            secondaryPresentation: nil
        )
    }
}

struct DriveCheckStatusProvider: TimelineProvider {
    func placeholder(in _: Context) -> DriveCheckStatusEntry {
        .previewSample()
    }

    func getSnapshot(in context: Context, completion: @escaping (DriveCheckStatusEntry) -> Void) {
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
    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<DriveCheckStatusEntry>) -> Void) {
        Task {
            // Polling loop: try to refresh, keep last-known-good on failure,
            // then return a timeline whose .after policy schedules the next poll.
            await WidgetTimelineRefresh.refresh(store: .shared)
            let timeline = WidgetTimelineBuilder.timeline(store: .shared, now: Date())
            let entries = timeline.entries.map { entry in
                DriveCheckStatusEntry(
                    date: entry.date,
                    presentation: entry.presentation,
                    secondaryPresentation: secondaryPresentation(at: entry.date, store: .shared)
                )
            }
            completion(Timeline(entries: entries, policy: timeline.policy))
        }
    }

    private func makeEntry(now: Date, store: SharedStore) -> DriveCheckStatusEntry {
        DriveCheckStatusEntry(
            date: now,
            presentation: WidgetTimelineBuilder.presentation(store: store, now: now),
            secondaryPresentation: secondaryPresentation(at: now, store: store)
        )
    }

    /// "Also watching" tile data — Pro-only, and only when a secondary region is configured.
    /// Reads the same `now` as the primary entry so both tiles' freshness advances together.
    private func secondaryPresentation(at now: Date, store: SharedStore) -> WidgetStatusPresentation? {
        guard store.loadIsPro(), let secondary = store.loadSecondaryRegion() else { return nil }
        return WidgetTimelineBuilder.presentation(store: store, region: secondary, now: now)
    }
}
