#if DEBUG
    import DriveCheckKit
    import SwiftUI
    import WidgetKit

    #Preview("Status · Small", as: .systemSmall) {
        DriveCheckStatusWidget()
    } timeline: {
        WidgetPreview.entry(.quiet, freshness: .fresh)
        WidgetPreview.entry(.alarm, freshness: .fresh)
        WidgetPreview.entry(.quiet, freshness: .aging)
        WidgetPreview.entry(.quiet, freshness: .expired)
        WidgetPreview.entry(.idle)
        WidgetPreview.entry(.error)
    }

    #Preview("Status · Medium", as: .systemMedium) {
        DriveCheckStatusWidget()
    } timeline: {
        WidgetPreview.entry(.quiet, freshness: .fresh)
        WidgetPreview.entry(.alarm, freshness: .fresh)
        WidgetPreview.entry(.alarm, freshness: .aging)
        WidgetPreview.entry(.alarm, freshness: .expired)
    }

    #Preview("Status · Lock Screen", as: .accessoryRectangular) {
        DriveCheckStatusWidget()
    } timeline: {
        WidgetPreview.entry(.quiet, freshness: .fresh)
        WidgetPreview.entry(.alarm, freshness: .fresh)
        WidgetPreview.entry(.quiet, freshness: .aging)
        WidgetPreview.entry(.quiet, freshness: .expired)
    }

    private enum WidgetPreview {
        static func entry(
            _ phase: DriveCheckActivityPhase,
            freshness: WidgetFreshnessTier = .fresh
        ) -> WidgetStatusTimelineEntry {
            let now = Date()
            let offset: TimeInterval = switch freshness {
            case .fresh: 0
            case .aging: -240
            case .expired: -900
            }
            return WidgetStatusTimelineEntry(
                date: now,
                presentation: WidgetStatusPresentation(
                    phase: phase,
                    regionTitle: AlertRegion.kyivCity.title,
                    checkedAt: phase == .idle ? nil : now.addingTimeInterval(offset),
                    freshness: freshness,
                    sourceLabel: "ubilling.net.ua"
                )
            )
        }
    }
#endif
