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
        let entry = makeEntry(configuration: configuration, allowPreviewSample: false)
        return Timeline(entries: [entry], policy: .after(WidgetTimelineBuilder.reloadDate(from: entry.date)))
    }

    private func makeEntry(configuration: SelectSecondaryRegionIntent,
                           allowPreviewSample: Bool) -> DriveCheckSecondaryRegionEntry {
        let store = SharedStore.shared
        if let configured = configuration.region {
            store.saveSecondaryRegion(configured)
        }
        let region = store.loadSecondaryRegion() ?? configuration.region ?? .kyivCity
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
                checkedAt: Date(),
                isStale: false
            )
        )
    }
}

struct DriveCheckSecondaryRegionView: View {
    let entry: DriveCheckSecondaryRegionEntry

    var body: some View {
        if let presentation = entry.presentation {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.region.title)
                    .font(.headline)
                Text(LocalizedStringKey(presentation.phase.titleKey))
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color(.systemBackground) }
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
