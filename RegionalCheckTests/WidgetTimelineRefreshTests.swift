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

    @Test
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
}
