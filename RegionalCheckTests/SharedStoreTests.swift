// swiftlint:disable force_unwrapping
import DriveCheckKit
import Foundation
import Testing

struct SharedStoreTests {
    @Test
    func roundTripsSnapshotRegionFollowsAndPro() {
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
            store.saveFollowsLocation(false)
            store.saveIsPro(true)

            #expect(store.loadSnapshot() == snapshot)
            #expect(store.loadRegion() == .kharkiv)
            #expect(store.loadFollowsLocation() == false)
            #expect(store.loadIsPro() == true)
        }
    }

    @Test
    func followsLocationDefaultsTrueWhenUnset() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            #expect(store.loadFollowsLocation() == true)
        }
    }

    @Test
    func migratesRegionFromLegacyStandardDefaults() throws {
        try TestDefaults.withTemporaryDefaults { suite in
            let standard = UserDefaults(suiteName: "SharedStoreTests.standard.\(UUID().uuidString)")!
            let legacyData = try JSONEncoder().encode(AlertRegion.chernihiv)
            standard.set(legacyData, forKey: SharedStoreKeys.legacyRegionV2)
            standard.set(false, forKey: SharedStoreKeys.legacyFollowsLocation)

            let store = SharedStore(userDefaults: suite, legacyDefaults: standard)
            store.migrateLegacyRegionIfNeeded()

            #expect(store.loadRegion() == .chernihiv)
            #expect(store.loadFollowsLocation() == false)
            #expect(standard.data(forKey: SharedStoreKeys.legacyRegionV2) == nil)
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
}
