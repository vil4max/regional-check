import DriveCheckKit
import Foundation
import Testing

struct WidgetTimelineRefreshTests {
    @Test
    func successfulFetchReplacesStoredSnapshot() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveSnapshot(TestFixtures.quietSnapshot(checkedAt: Date(timeIntervalSince1970: 1)))
            let fresh = TestFixtures.quietSnapshot(checkedAt: Date(timeIntervalSince1970: 2))

            await WidgetTimelineRefresh.refresh(store: store, provider: MockStatusProvider(snapshot: fresh))

            #expect(store.loadSnapshot() == fresh)
        }
    }

    @Test("REQ-REFRESH-008 a failed widget fetch keeps the last known good snapshot")
    func failedFetchKeepsLastKnownGoodSnapshot() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let lastKnownGood = TestFixtures.quietSnapshot(checkedAt: Date(timeIntervalSince1970: 1))
            store.saveSnapshot(lastKnownGood)

            await WidgetTimelineRefresh.refresh(
                store: store,
                provider: MockStatusProvider(error: URLError(.notConnectedToInternet))
            )

            #expect(store.loadSnapshot() == lastKnownGood)
        }
    }

    @Test("REQ-PROVIDER-002 a widget poll inside a stored 429 window does not fetch")
    func pollInsideRateLimitWindowIsSkipped() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let now = Date(timeIntervalSince1970: 1_000)
            let held = TestFixtures.quietSnapshot(checkedAt: Date(timeIntervalSince1970: 1))
            store.saveSnapshot(held)
            store.saveRateLimitedUntil(now.addingTimeInterval(60))
            let fresh = TestFixtures.quietSnapshot(checkedAt: Date(timeIntervalSince1970: 2))

            await WidgetTimelineRefresh.refresh(store: store, provider: MockStatusProvider(snapshot: fresh), now: now)

            #expect(store.loadSnapshot() == held)
        }
    }

    @Test("REQ-PROVIDER-002 a widget poll that gets 429 stores a capped window")
    func rateLimitedPollStoresCappedWindow() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let now = Date(timeIntervalSince1970: 1_000)
            let error = UbillingError.rateLimited(retryAfter: now.addingTimeInterval(86_400))

            await WidgetTimelineRefresh.refresh(store: store, provider: MockStatusProvider(error: error), now: now)

            #expect(store.loadRateLimitedUntil() == now.addingTimeInterval(RetryAfterParser.maxHold))
        }
    }
}
