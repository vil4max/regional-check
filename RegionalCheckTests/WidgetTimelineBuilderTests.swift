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
            #expect(presentation.nextUpdateAt == nil)
        }
    }

    @Test
    func freshStateShowsRealStatus() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let checkedAt = Date(timeIntervalSince1970: 1000)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "feed",
                    serverCachedAt: checkedAt,
                    fetchedAt: checkedAt,
                    statuses: [.kyivCity: .quiet]
                )
            )
            // 60 seconds after check -> Fresh
            let presentation = WidgetTimelineBuilder.presentation(
                store: store,
                now: checkedAt.addingTimeInterval(60)
            )
            #expect(presentation.freshness == .fresh)
            #expect(!presentation.isStale)
            #expect(presentation.titleKey == "All Clear")
            #expect(presentation.symbolName == "checkmark.circle.fill")
        }
    }

    @Test
    func agingStatePreservesStatusWithWarning() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let checkedAt = Date(timeIntervalSince1970: 1000)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "feed",
                    serverCachedAt: checkedAt,
                    fetchedAt: checkedAt,
                    statuses: [.kyivCity: .quiet]
                )
            )
            // 4 minutes after check (between 180s and 600s) -> Aging
            let presentation = WidgetTimelineBuilder.presentation(
                store: store,
                now: checkedAt.addingTimeInterval(240)
            )
            #expect(presentation.freshness == .aging)
            #expect(presentation.isStale)
            // Real status title and icon MUST be preserved during temporary network delay!
            #expect(presentation.titleKey == "All Clear")
            #expect(presentation.symbolName == "checkmark.circle.fill")
        }
    }

    @Test
    func expiredPreservesLastKnownStatus() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let checkedAt = Date(timeIntervalSince1970: 1000)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "feed",
                    serverCachedAt: checkedAt,
                    fetchedAt: checkedAt,
                    statuses: [.kyivCity: .quiet]
                )
            )
            // 15 minutes after check (>= 600s) -> Expired, but last-known
            // quiet must be preserved instead of a terminal "no connection".
            let presentation = WidgetTimelineBuilder.presentation(
                store: store,
                now: checkedAt.addingTimeInterval(900)
            )
            #expect(presentation.freshness == .expired)
            #expect(presentation.isStale)
            #expect(presentation.titleKey == "All Clear")
            #expect(presentation.symbolName == "checkmark.circle.fill")
        }
    }

    @Test
    func expiredPreservesAlarm() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kyivCity)
            let checkedAt = Date(timeIntervalSince1970: 1000)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "feed",
                    serverCachedAt: checkedAt,
                    fetchedAt: checkedAt,
                    statuses: [.kyivCity: .alarm]
                )
            )
            let presentation = WidgetTimelineBuilder.presentation(
                store: store,
                now: checkedAt.addingTimeInterval(900)
            )
            #expect(presentation.freshness == .expired)
            #expect(presentation.titleKey == "Alert Active")
            #expect(presentation.symbolName == "exclamationmark.circle.fill")
        }
    }

    @Test
    func missingSnapshotSchedulesPolling() {
        TestDefaults.withTemporaryDefaults { defaults in
            let now = Date(timeIntervalSince1970: 2000)
            let timeline = WidgetTimelineBuilder.timeline(
                store: SharedStore(userDefaults: defaults),
                now: now
            )

            #expect(timeline.entries.count == 1)
            #expect(timeline.entries.first?.presentation.phase == .idle)
            #expect(timeline.entries.first?.presentation.checkedAt == nil)
            #expect(timeline.entries.first?.presentation.nextUpdateAt == nil)
            // Idle must poll for first data instead of parking in .never.
            #expect(Self.isAfterPolicy(timeline))
            let expected = now.addingTimeInterval(WidgetTimelineBuilder.pollIntervalIdle)
            let computed = WidgetTimelineBuilder.nextPollDate(from: now, phase: .idle)
            #expect(computed.timeIntervalSince1970 == expected.timeIntervalSince1970)
        }
    }

    @Test
    func timelineGeneratesThreeTierEntries() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let checkedAt = Date(timeIntervalSince1970: 1000)
            let fetchedAt = Date(timeIntervalSince1970: 1000)
            store.saveSnapshot(AlertsSnapshot(
                source: "feed",
                serverCachedAt: checkedAt,
                fetchedAt: fetchedAt,
                statuses: [.kyivCity: .quiet]
            ))
            let now = checkedAt.addingTimeInterval(10) // 1010

            let timeline = WidgetTimelineBuilder.timeline(store: store, region: .kyivCity, now: now)

            // Expect entries at now (1010), agingDate (1180 = 1000 + 180), and expiredDate (1600 = 1000 + 600)
            #expect(timeline.entries.count == 3)

            let entry1 = timeline.entries[0]
            #expect(entry1.date == now)
            #expect(entry1.presentation.freshness == .fresh)
            #expect(entry1.presentation.titleKey == "All Clear")

            let entry2 = timeline.entries[1]
            #expect(entry2.date == Date(timeIntervalSince1970: 1180))
            #expect(entry2.presentation.freshness == .aging)
            #expect(entry2.presentation.titleKey == "All Clear")

            let entry3 = timeline.entries[2]
            #expect(entry3.date == Date(timeIntervalSince1970: 1600))
            #expect(entry3.presentation.freshness == .expired)
            // Expired preserves last-known status; only freshness marks staleness.
            #expect(entry3.presentation.titleKey == "All Clear")

            // Polling loop: .after schedules the next getTimeline + fetch.
            #expect(Self.isAfterPolicy(timeline))
            let expectedPoll = now.addingTimeInterval(WidgetTimelineBuilder.pollIntervalQuiet)
            let computedPoll = WidgetTimelineBuilder.nextPollDate(from: now, phase: .quiet)
            #expect(computedPoll.timeIntervalSince1970 == expectedPoll.timeIntervalSince1970)
            #expect(WidgetTimelineBuilder.pollInterval(for: .alarm) == WidgetTimelineBuilder.pollIntervalAlarm)
            #expect(WidgetTimelineBuilder.pollInterval(for: .quiet) == WidgetTimelineBuilder.pollIntervalQuiet)
        }
    }

    private static func isAfterPolicy(_ timeline: Timeline<WidgetStatusTimelineEntry>) -> Bool {
        timeline.policy != .never
    }

    @Test
    func missingRegionRemainsUnavailable() {
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

            #expect(timeline.entries.first?.presentation.titleKey == "Region Unavailable")
            #expect(timeline.entries.allSatisfy { $0.presentation.phase == .error })
            #expect(timeline.entries.allSatisfy { $0.presentation.sourceLabel == nil })
        }
    }
}
