#if DEBUG
    import ActivityKit
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
        WidgetPreview.entry(.alarm, freshness: .expired)
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
        WidgetPreview.entry(.quiet, freshness: .expired)
    }

    #Preview("Status · Lock Screen", as: .accessoryRectangular) {
        DriveCheckStatusWidget()
    } timeline: {
        WidgetPreview.entry(.quiet, freshness: .fresh)
        WidgetPreview.entry(.alarm, freshness: .fresh)
        WidgetPreview.entry(.quiet, freshness: .aging)
        WidgetPreview.entry(.quiet, freshness: .expired)
    }

    #Preview("Live Activity", as: .content, using: DriveCheckActivityAttributes()) {
        DriveCheckLiveActivity()
    } contentStates: {
        WidgetPreview.activityState(.alarm, startedMinutesAgo: 12)
        WidgetPreview.activityState(.alarm)
        WidgetPreview.activityState(.alarm, isStale: true, startedMinutesAgo: 40)
        WidgetPreview.activityState(.quiet, isStale: true)
        WidgetPreview.activityState(.idle)
    }

    #Preview("Island expanded", as: .dynamicIsland(.expanded), using: DriveCheckActivityAttributes()) {
        DriveCheckLiveActivity()
    } contentStates: {
        WidgetPreview.activityState(.alarm, startedMinutesAgo: 12)
        WidgetPreview.activityState(.alarm, isStale: true, startedMinutesAgo: 40)
    }

    #Preview("Island compact", as: .dynamicIsland(.compact), using: DriveCheckActivityAttributes()) {
        DriveCheckLiveActivity()
    } contentStates: {
        WidgetPreview.activityState(.alarm, startedMinutesAgo: 12)
        WidgetPreview.activityState(.quiet, isStale: true)
    }

    #Preview("Island minimal", as: .dynamicIsland(.minimal), using: DriveCheckActivityAttributes()) {
        DriveCheckLiveActivity()
    } contentStates: {
        WidgetPreview.activityState(.alarm, startedMinutesAgo: 12)
    }

    private enum WidgetPreview {
        static func entry(
            _ phase: DriveCheckActivityPhase,
            freshness: WidgetFreshnessTier = .fresh
        ) -> WidgetStatusTimelineEntry {
            WidgetStatusTimelineEntry(date: Date(), presentation: presentation(phase, freshness: freshness))
        }

        static func activityState(
            _ phase: DriveCheckActivityPhase,
            isStale: Bool = false,
            startedMinutesAgo: Double? = nil
        ) -> DriveCheckActivityAttributes.ContentState {
            DriveCheckActivityAttributes.ContentState(
                phase: phase,
                regionTitle: AlertRegion.kharkiv.title,
                checkedAt: phase == .idle ? nil : Date().addingTimeInterval(-900),
                sourceLabel: "ubilling.net.ua",
                isStale: isStale,
                alertStartedAt: startedMinutesAgo.map { Date().addingTimeInterval(-$0 * 60) }
            )
        }

        private static func presentation(
            _ phase: DriveCheckActivityPhase,
            freshness: WidgetFreshnessTier
        ) -> WidgetStatusPresentation {
            let now = Date()
            let offset: TimeInterval =
                switch freshness {
                case .fresh: 0
                case .aging: -240
                case .expired: -900
                }
            return WidgetStatusPresentation(
                phase: phase,
                regionTitle: AlertRegion.kyivCity.title,
                checkedAt: phase == .idle ? nil : now.addingTimeInterval(offset),
                freshness: freshness
            )
        }
    }
#endif
