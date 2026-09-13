#if DEBUG
    import DriveCheckKit
    import SwiftUI
    import WidgetKit

    #Preview("Status · Small", as: .systemSmall) {
        DriveCheckStatusWidget()
    } timeline: {
        WidgetPreview.entry(.quiet)
        WidgetPreview.entry(.alarm)
        WidgetPreview.entry(.quiet, isStale: true)
        WidgetPreview.entry(.idle)
        WidgetPreview.entry(.error)
    }

    #Preview("Status · Medium", as: .systemMedium) {
        DriveCheckStatusWidget()
    } timeline: {
        WidgetPreview.entry(.quiet)
        WidgetPreview.entry(.alarm)
        WidgetPreview.entry(.alarm, isStale: true)
    }

    #Preview("Status · Lock Screen", as: .accessoryRectangular) {
        DriveCheckStatusWidget()
    } timeline: {
        WidgetPreview.entry(.quiet)
        WidgetPreview.entry(.alarm)
        WidgetPreview.entry(.quiet, isStale: true)
    }

    private enum WidgetPreview {
        static func entry(_ phase: DriveCheckActivityPhase, isStale: Bool = false) -> WidgetStatusTimelineEntry {
            let now = Date()
            return WidgetStatusTimelineEntry(
                date: now,
                presentation: WidgetStatusPresentation(
                    phase: phase,
                    regionTitle: AlertRegion.kyivCity.title,
                    checkedAt: phase == .idle ? nil : now.addingTimeInterval(isStale ? -300 : 0),
                    isStale: isStale,
                    sourceLabel: "ubilling.net.ua"
                )
            )
        }
    }
#endif
