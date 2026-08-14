import DriveCheckKit
import Foundation
import Testing

struct ControlStatusValueBuilderTests {
    @Test
    func readsPhaseAndRegionFromSharedStore() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveRegion(.kharkiv)
            store.saveSnapshot(
                AlertsSnapshot(
                    source: "feed",
                    serverCachedAt: Date(timeIntervalSince1970: 50),
                    fetchedAt: Date(timeIntervalSince1970: 50),
                    statuses: [.kharkiv: .alarm]
                )
            )
            let value = ControlStatusValueBuilder.value(from: store)
            #expect(value.phase == .alarm)
            #expect(value.regionTitle == AlertRegion.kharkiv.title)
        }
    }
}
