import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// ADR 0014: the functional gates grant everything while Pro is hidden; the entitlement model
/// underneath keeps reporting the truth, which `SubscriptionTests` covers.
@MainActor
struct ProHiddenGateTests {
    @Test("REQ-SURF-007 a user without an entitlement is allowed every previously Pro-gated capability")
    func gatesAllowEverythingWithoutAnEntitlement() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let manager = makeManager(defaults: defaults)
            await manager.start()

            #expect(manager.isPro == false)
            #expect(manager.allows(.extendedDetail))
            #expect(manager.allows(.liveActivity))
        }
    }

    @Test("REQ-SURF-007 the user's own Live Activity switch still applies once the capability is free")
    func liveActivitySwitchStillApplies() {
        TestDefaults.withTemporaryDefaults { defaults in
            let manager = makeManager(defaults: defaults)

            manager.setLiveActivityEnabled(false)
            #expect(manager.allows(.liveActivity) == false)

            manager.setLiveActivityEnabled(true)
            #expect(manager.allows(.liveActivity))
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

            // `start()` subscribes from an unstructured task, so a push can land before the
            // listener exists; pushing until it is heard avoids sleeping for a guessed delay.
            for _ in 0 ..< 50 where !manager.isPro {
                service.push(.active(TestFixtures.activeEntitlement))
                try? await Task.sleep(for: .milliseconds(20))
            }

            #expect(manager.isPro)
        }
    }

    private func makeManager(
        service: FakeSubscriptionService = FakeSubscriptionService(products: [], entitlement: .none),
        defaults: UserDefaults
    ) -> SubscriptionManager {
        SubscriptionManager(
            service: service,
            cache: EntitlementCache(userDefaults: defaults),
            userDefaults: defaults,
            entitlementPersistence: SharedStore(userDefaults: defaults),
            widgetReloader: TestWidgetReloader()
        )
    }
}
