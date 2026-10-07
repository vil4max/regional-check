import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct EntitlementStreamTests {
    @Test("Entitlement changes persist and reload widgets only when isPro changes")
    func grantRepeatUnverifiedAndRevokePreserveSideEffects() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let service = FakeSubscriptionService(products: [], entitlement: .none)
            let persistence = EntitlementWriteSpy()
            let reloader = RegionReloadSpy()
            let manager = SubscriptionManager(
                service: service,
                cache: EntitlementCache(userDefaults: defaults),
                entitlementPersistence: persistence,
                widgetReloader: reloader
            )
            var notifications = manager.entitlementChanges().makeAsyncIterator()
            #expect(await manager.restore() == .empty)
            #expect(persistence.values.isEmpty)
            #expect(reloader.reloadCount == 0)

            service.restoreEntitlement = .active(TestFixtures.activeEntitlement)
            #expect(await manager.restore() == .restored)
            #expect(await notifications.next() != nil)
            #expect(persistence.values == [true])
            #expect(reloader.reloadCount == 1)

            #expect(await manager.restore() == .restored)
            service.restoreEntitlement = .unverified
            #expect(await manager.restore() == .failed)
            #expect(persistence.values == [true])
            #expect(reloader.reloadCount == 1)

            service.restoreEntitlement = EntitlementVerification.none
            #expect(await manager.restore() == .empty)
            #expect(await notifications.next() != nil)
            #expect(persistence.values == [true, false])
            #expect(reloader.reloadCount == 2)
        }
    }

    @Test("Entitlement grant and revoke still reconcile the Live Activity controller")
    func entitlementStreamStillReconciles() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let service = FakeSubscriptionService(products: [], entitlement: .none)
            let manager = SubscriptionManager(
                service: service,
                cache: EntitlementCache(userDefaults: defaults),
                entitlementPersistence: EntitlementWriteSpy(),
                widgetReloader: TestWidgetReloader()
            )
            let preference = LiveActivityPreferenceStore(userDefaults: defaults)
            let probe = PreferenceReadProbe(store: preference)
            let changes = manager.entitlementChanges()
            let controller = LiveActivityController(
                preference: probe,
                entitlementChanges: { changes },
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true)
            )
            var reads = probe.reads.stream.makeAsyncIterator()
            #expect(await reads.next() == true)
            await controller.settle()

            service.restoreEntitlement = .active(TestFixtures.activeEntitlement)
            _ = await manager.restore()
            #expect(await reads.next() == true)
            await controller.settle()

            service.restoreEntitlement = EntitlementVerification.none
            _ = await manager.restore()
            #expect(await reads.next() == true)
            await controller.settle()
            #expect(preference.isEnabled)
        }
    }
}

private final class EntitlementWriteSpy: EntitlementPersisting {
    private let writes = Mutex<[Bool]>([])
    var values: [Bool] { writes.withLock { $0 } }
    func saveIsPro(_ isPro: Bool) { writes.withLock { $0.append(isPro) } }
}
