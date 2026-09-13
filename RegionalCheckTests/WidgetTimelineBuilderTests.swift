import DriveCheckKit
import Foundation
import Testing
import WidgetKit

struct WidgetTimelineBuilderTests {
    @Test
    func idleWhenSnapshotMissing() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let presentation = WidgetTimelineBuilder.presentation(store: store)
            #expect(presentation.phase == .idle)
            #expect(presentation.regionTitle == AlertRegion.kyivCity.title)
            #expect(presentation.titleKey == "widget.status.noData")
            #expect(presentation.symbolName == "questionmark.circle.fill")
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
            #expect(presentation.titleKey == "widget.status.stale")
            #expect(presentation.symbolName == "clock.badge.exclamationmark")
        }
    }

    @Test
    func missingSnapshotDoesNotSchedulePolling() {
        TestDefaults.withTemporaryDefaults { defaults in
            let timeline = WidgetTimelineBuilder.timeline(store: SharedStore(userDefaults: defaults))

            #expect(timeline.policy == .never)
            #expect(timeline.entries.count == 1)
            #expect(timeline.entries.first?.presentation.phase == .idle)
            #expect(timeline.entries.first?.presentation.checkedAt == nil)
        }
    }

    @Test(arguments: [0.0, 119.0, 120.0, 121.0, 3600.0])
    func timelineExpiresFromSourceTimeWithoutPolling(age: TimeInterval) {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let checkedAt = Date(timeIntervalSince1970: 500)
            store.saveIsPro(true)
            store.saveSnapshot(AlertsSnapshot(
                source: "feed",
                serverCachedAt: checkedAt,
                fetchedAt: checkedAt.addingTimeInterval(90),
                statuses: [.kyivCity: .quiet, .lviv: .alarm]
            ))
            let now = checkedAt.addingTimeInterval(age)

            let timeline = WidgetTimelineBuilder.timeline(store: store, region: .lviv, now: now)

            #expect(timeline.policy == .never)
            #expect(timeline.entries.first?.date == now)
            #expect(timeline.entries.first?.presentation.isStale == (age >= 120))
            #expect(timeline.entries.first?.presentation.titleKey == (age >= 120
                    ? "widget.status.stale" : "Alert Active"))
            #expect(timeline.entries.count == (age < 120 ? 2 : 1))
            #expect(timeline.entries.last?.presentation.isStale == true)
            #expect(timeline.entries.last?.presentation.titleKey == "widget.status.stale")
            if age < 120 {
                #expect(timeline.entries.last?.date == checkedAt.addingTimeInterval(120))
            }
            for entry in timeline.entries {
                #expect(entry.presentation.phase == .alarm)
                #expect(entry.presentation.regionTitle == AlertRegion.lviv.title)
                #expect(entry.presentation.checkedAt == checkedAt)
                #expect(entry.presentation.sourceLabel == "feed")
            }
        }
    }

    @Test
    func missingRegionRemainsUnavailableWhenTimelineExpires() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let fetchedAt = Date(timeIntervalSince1970: 500)
            store.saveSnapshot(AlertsSnapshot(
                source: "feed",
                serverCachedAt: nil,
                fetchedAt: fetchedAt,
                statuses: [.kyivCity: .quiet]
            ))

            let timeline = WidgetTimelineBuilder.timeline(store: store, region: .lviv, now: fetchedAt)

            #expect(timeline.policy == .never)
            #expect(timeline.entries.count == 2)
            #expect(timeline.entries.first?.presentation.titleKey == "Region Unavailable")
            #expect(timeline.entries.last?.date == fetchedAt.addingTimeInterval(120))
            #expect(timeline.entries.allSatisfy { $0.presentation.phase == .error })
            #expect(timeline.entries.allSatisfy { $0.presentation.sourceLabel == nil })
        }
    }
}
