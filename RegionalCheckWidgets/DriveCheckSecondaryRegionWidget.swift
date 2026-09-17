import AppIntents
import DriveCheckKit
import SwiftUI
import WidgetKit

struct DriveCheckSecondaryRegionWidget: Widget {
    let kind = "DriveCheckSecondaryRegionWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectSecondaryRegionIntent.self,
            provider: DriveCheckSecondaryRegionProvider()
        ) { entry in
            DriveCheckSecondaryRegionView(entry: entry)
        }
        .configurationDisplayName("widget.secondary.title")
        .description("widget.secondary.description")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct SelectSecondaryRegionIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.secondary.configure"

    @Parameter(title: "intent.region.parameter")
    var region: AlertRegion?

    func perform() async throws -> some IntentResult {
        if let region {
            SharedStore.shared.saveSecondaryRegion(region)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct DriveCheckSecondaryRegionProvider: AppIntentTimelineProvider {
    typealias Entry = DriveCheckSecondaryRegionEntry
    typealias Intent = SelectSecondaryRegionIntent

    func placeholder(in _: Context) -> DriveCheckSecondaryRegionEntry {
        .previewSample(region: .lviv)
    }

    func snapshot(for configuration: SelectSecondaryRegionIntent,
                  in _: Context) async -> DriveCheckSecondaryRegionEntry {
        makeEntry(configuration: configuration, allowPreviewSample: true)
    }

    func timeline(for configuration: SelectSecondaryRegionIntent,
                  in _: Context) async -> Timeline<DriveCheckSecondaryRegionEntry> {
        let store = SharedStore.shared
        let region = selectedRegion(configuration: configuration, store: store)
        let now = Date()
        guard store.loadIsPro() else {
            let entry = DriveCheckSecondaryRegionEntry(date: now, region: region, presentation: nil)
            return Timeline(entries: [entry], policy: .never)
        }
        await WidgetTimelineRefresh.refresh(store: store)
        let pollNow = Date()
        let timeline = WidgetTimelineBuilder.timeline(store: store, region: region, now: pollNow)
        let entries = timeline.entries.map {
            DriveCheckSecondaryRegionEntry(date: $0.date, region: region, presentation: $0.presentation)
        }
        return Timeline(entries: entries, policy: timeline.policy)
    }

    private func makeEntry(configuration: SelectSecondaryRegionIntent,
                           allowPreviewSample: Bool) -> DriveCheckSecondaryRegionEntry {
        let store = SharedStore.shared
        let region = selectedRegion(configuration: configuration, store: store)
        if store.loadIsPro() {
            return DriveCheckSecondaryRegionEntry(
                date: Date(),
                region: region,
                presentation: WidgetTimelineBuilder.presentation(store: store, region: region)
            )
        }
        if allowPreviewSample {
            return .previewSample(region: region)
        }
        return DriveCheckSecondaryRegionEntry(date: Date(), region: region, presentation: nil)
    }

    private func selectedRegion(configuration: SelectSecondaryRegionIntent, store: SharedStore) -> AlertRegion {
        if let configured = configuration.region, configured != store.loadSecondaryRegion() {
            store.saveSecondaryRegion(configured)
        }
        return configuration.region ?? store.loadSecondaryRegion() ?? .kyivCity
    }
}

struct DriveCheckSecondaryRegionEntry: TimelineEntry {
    let date: Date
    let region: AlertRegion
    let presentation: WidgetStatusPresentation?

    static func previewSample(region: AlertRegion) -> DriveCheckSecondaryRegionEntry {
        DriveCheckSecondaryRegionEntry(
            date: Date(),
            region: region,
            presentation: WidgetStatusPresentation(
                phase: .quiet,
                regionTitle: region.title,
                checkedAt: Date()
            )
        )
    }
}

struct DriveCheckSecondaryRegionView: View {
    let entry: DriveCheckSecondaryRegionEntry

    var body: some View {
        if let presentation = entry.presentation {
            DriveCheckStatusWidgetView(entry: WidgetStatusTimelineEntry(date: entry.date, presentation: presentation))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.region.title)
                    .font(.headline)
                Text("widget.secondary.proRequired")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color(.systemBackground) }
        }
    }
}
