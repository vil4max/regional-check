// swiftlint:disable force_unwrapping
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct SharedStoreTests {
    @Test
    func roundTripsSnapshotRegionAndPro() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let snapshot = AlertsSnapshot(
                source: "test",
                serverCachedAt: Date(timeIntervalSince1970: 100),
                fetchedAt: Date(timeIntervalSince1970: 200),
                statuses: [.kyivCity: .alarm]
            )
            store.saveSnapshot(snapshot)
            store.saveRegion(.kharkiv)
            store.saveIsPro(true)

            #expect(store.loadSnapshot() == snapshot)
            #expect(store.loadRegion() == .kharkiv)
            // REQ-SURF-007 pins `loadIsPro()` to true, so the stored key is what proves the real
            // entitlement is still recorded for the release that reads it again.
            #expect(defaults.bool(forKey: SharedStoreKeys.isPro))
        }
    }

    @Test("REQ-REGION-002 a legacy region in standard defaults migrates to the shared store")
    func migratesRegionFromLegacyStandardDefaults() throws {
        try TestDefaults.withTemporaryDefaults { suite in
            let standard = UserDefaults(suiteName: "SharedStoreTests.standard.\(UUID().uuidString)")!
            let legacyData = try JSONEncoder().encode(AlertRegion.chernihiv)
            standard.set(legacyData, forKey: SharedStoreKeys.legacyRegionV2)
            standard.set(false, forKey: SharedStoreKeys.legacyFollowsLocation)

            let store = SharedStore(userDefaults: suite, legacyDefaults: standard)
            store.migrateLegacyRegionIfNeeded()

            #expect(store.loadRegion() == .chernihiv)
            #expect(standard.data(forKey: SharedStoreKeys.legacyRegionV2) == nil)
            // The follow-location flag is vestigial: the legacy copy is removed without being
            // carried into the shared store, where nothing would read it.
            #expect(standard.object(forKey: SharedStoreKeys.legacyFollowsLocation) == nil)
            #expect(suite.object(forKey: SharedStoreKeys.followsLocation) == nil)
        }
    }

    @Test
    func migratesEntitlementBlobFromStandardDefaults() {
        TestDefaults.withTemporaryDefaults { suite in
            let standard = UserDefaults(suiteName: "SharedStoreTests.standard.\(UUID().uuidString)")!
            let payload = Data("legacy-entitlement".utf8)
            standard.set(payload, forKey: SharedStoreKeys.legacyEntitlement)

            let store = SharedStore(userDefaults: suite, legacyDefaults: standard)
            store.migrateLegacyEntitlementIfNeeded()

            #expect(suite.data(forKey: SharedStoreKeys.legacyEntitlement) == payload)
            #expect(standard.data(forKey: SharedStoreKeys.legacyEntitlement) == nil)
        }
    }

    /// The key is spelled out: the test pins the on-disk name 2.x wrote, not a Swift constant.
    @Test("the retired second region is removed from the App Group when the region store opens")
    func retiredSecondaryRegionIsRemovedOnceAndTheRegionIsKept() throws {
        try TestDefaults.withTemporaryDefaults { defaults in
            let retiredKey = "shared.secondaryRegion.v1"
            try defaults.set(JSONEncoder().encode(AlertRegion.odesa), forKey: retiredKey)
            let shared = SharedStore(userDefaults: defaults, legacyDefaults: defaults)
            shared.saveRegion(.lviv)

            let store = RegionStore(sharedStore: shared)

            #expect(defaults.object(forKey: retiredKey) == nil)
            #expect(store.load() == .lviv)

            // A second open has nothing left to remove and must not disturb the region.
            #expect(RegionStore(sharedStore: shared).load() == .lviv)
            #expect(defaults.object(forKey: retiredKey) == nil)
        }
    }

    @Test("REQ-REGION-002 migration never overwrites an existing region or runs twice")
    func migrationDoesNotOverwriteExistingRegionOrMoveLegacyValuesTwice() throws {
        try TestDefaults.withTemporaryDefaults { suite in
            let standard = UserDefaults(suiteName: "SharedStoreTests.standard.\(UUID().uuidString)")!
            let store = SharedStore(userDefaults: suite, legacyDefaults: standard)
            store.saveRegion(.lviv)
            try standard.set(JSONEncoder().encode(AlertRegion.kharkiv), forKey: SharedStoreKeys.legacyRegionV2)

            store.migrateLegacyRegionIfNeeded()

            #expect(store.loadRegion() == .lviv)
            #expect(standard.data(forKey: SharedStoreKeys.legacyRegionV2) != nil)
        }
    }
}
