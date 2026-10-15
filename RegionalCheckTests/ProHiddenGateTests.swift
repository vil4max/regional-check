import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// ADR 0016: the functional gates grant everything with or without Pro; the entitlement model
/// underneath keeps reporting the truth, which `SubscriptionTests` covers.
@MainActor
struct ProHiddenGateTests {
    @Test("REQ-SURF-007 PRO-COSMETIC AC-6 an owner of the cosmetic bundle gets exactly the same capabilities")
    func ownerGetsTheSameCapabilities() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let owned = EntitlementSnapshot(
                productID: SubscriptionProductID.cosmetic.rawValue,
                expirationDate: nil,
                isActive: true,
                source: "storekit",
                verifiedAt: Date(timeIntervalSince1970: 1)
            )
            let manager = makeManager(
                service: FakeSubscriptionService(products: [], entitlement: .active(owned)),
                defaults: defaults
            )
            await manager.start()

            #expect(manager.isPro)
            #expect(manager.allows(.extendedDetail))
            #expect(SharedStore(userDefaults: defaults).loadIsPro())
        }
    }

    @Test("REQ-SURF-007 a user without an entitlement is allowed every previously Pro-gated capability")
    func gatesAllowEverythingWithoutAnEntitlement() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let manager = makeManager(defaults: defaults)
            await manager.start()

            #expect(manager.isPro == false)
            #expect(manager.allows(.extendedDetail))
            let preference = LiveActivityPreferenceStore(userDefaults: defaults)
            let controller = LiveActivityController(
                preference: preference,
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
                host: FixtureLiveActivityHost()
            )
            #expect(controller.canRunActivity)
        }
    }

    @Test("REQ-SURF-007 the user's own Live Activity switch still applies once the capability is free")
    func liveActivitySwitchStillApplies() {
        TestDefaults.withTemporaryDefaults { defaults in
            let manager = makeManager(defaults: defaults)

            let preference = LiveActivityPreferenceStore(userDefaults: defaults)
            let controller = LiveActivityController(
                preference: preference,
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
                host: FixtureLiveActivityHost()
            )
            preference.setEnabled(false)
            #expect(!controller.canRunActivity)

            preference.setEnabled(true)
            #expect(controller.canRunActivity)
            #expect(!manager.isPro)
        }
    }

    @Test("REQ-SURF-007 widgets and Siri read the shared gate as granted whatever entitlement is stored")
    func sharedGateIsGrantedWhateverIsStored() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            #expect(store.loadIsPro())

            store.saveIsPro(false)
            #expect(store.loadIsPro())
        }
    }

    @Test("REQ-SURF-007 the session start still listens for renewals with no Pro surface presented")
    func startStillAppliesTransactionUpdates() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let service = FakeSubscriptionService(products: [], entitlement: .none)
            let manager = makeManager(service: service, defaults: defaults)
            await manager.start()

            // start() subscribes before its first await, so one push is heard; the listener
            // applies it on its own task.
            service.push(.active(TestFixtures.activeEntitlement))
            #expect(await eventually { manager.isPro })
        }
    }

    private func makeManager(
        service: FakeSubscriptionService = FakeSubscriptionService(products: [], entitlement: .none),
        defaults: UserDefaults
    ) -> SubscriptionManager {
        SubscriptionManager(
            service: service,
            cache: EntitlementCache(userDefaults: defaults),
            entitlementPersistence: SharedStore(userDefaults: defaults),
            widgetReloader: TestWidgetReloader()
        )
    }
}
