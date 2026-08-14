import DriveCheckKit
import Foundation
import Testing

struct WidgetTimelineBuilderTests {
    @Test
    func idleWhenSnapshotMissing() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let presentation = WidgetTimelineBuilder.presentation(store: store)
            #expect(presentation.phase == .idle)
            #expect(presentation.regionTitle == AlertRegion.kyivCity.title)
        }
    }

    @Test
    func marksStaleFromCheckedAt() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let checkedAt = Date(timeIntervalSince1970: 100)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "feed",
                    serverCachedAt: checkedAt,
                    fetchedAt: checkedAt,
                    statuses: [.kyivCity: .quiet]
                )
            )
            let presentation = WidgetTimelineBuilder.presentation(
                store: store,
                now: checkedAt.addingTimeInterval(121),
                staleThreshold: 120
            )
            #expect(presentation.isStale)
            #expect(presentation.phase == .quiet)
        }
    }

    @Test
    func reloadDateIsOneMinuteAhead() {
        let now = Date(timeIntervalSince1970: 500)
        let reload = WidgetTimelineBuilder.reloadDate(from: now)
        #expect(reload == now.addingTimeInterval(60))
    }
}
