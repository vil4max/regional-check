// swiftlint:disable force_unwrapping
import DriveCheckKit
import Foundation
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

    @Test
    func secondaryRegionCanBeClearedAndMalformedDataIsIgnored() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveSecondaryRegion(.odesa)
            #expect(store.loadSecondaryRegion() == .odesa)

            store.saveSecondaryRegion(nil)
            #expect(store.loadSecondaryRegion() == nil)

            defaults.set(Data("invalid".utf8), forKey: SharedStoreKeys.secondaryRegion)
            #expect(store.loadSecondaryRegion() == nil)
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
