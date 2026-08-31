// swiftlint:disable type_body_length
import Foundation
@testable import RegionalCheck
import Testing

struct SubscriptionTests {
    @Test
    func statusSourceLabel_hidesRawFeedName() {
        TestLocale.english {
            let alertFeed = String(localized: "status.source.alertFeed")
            let external = String(localized: "status.source.external")
            #expect(StatusSourceLabel.displayName(for: "Mørk Skogen API (default)") == alertFeed)
            #expect(StatusSourceLabel.displayName(for: "mork skogen") == alertFeed)
            #expect(StatusSourceLabel.displayName(for: "unknown-provider-xyz") == external)
            #expect(StatusSourceLabel.displayName(for: nil) == external)
            #expect(StatusSourceLabel.displayName(for: "") == external)
        }
    }

    @Test
    func entitlementCache_roundTripsActiveSnapshot() {
        TestDefaults.withTemporaryDefaults { defaults in
            let cache = EntitlementCache(userDefaults: defaults)
            let snapshot = EntitlementSnapshot(
                productID: SubscriptionProductID.yearly.rawValue,
                expirationDate: Date().addingTimeInterval(3600),
                isActive: true,
                source: "storekit",
                verifiedAt: Date(timeIntervalSince1970: 1)
            )
            cache.save(snapshot)
            #expect(cache.load() == snapshot)
            cache.clear()
            #expect(cache.load() == nil)
        }
    }

    @Test
    @MainActor
    func subscriptionManager_usesCachedActiveEntitlement() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let cache = EntitlementCache(userDefaults: defaults)
            cache.save(
                EntitlementSnapshot(
                    productID: SubscriptionProductID.monthly.rawValue,
                    expirationDate: Date().addingTimeInterval(86400),
                    isActive: true,
                    source: "storekit",
                    verifiedAt: Date()
                )
            )
            let service = FakeSubscriptionService(
                products: [
                    SubscriptionProduct(
                        id: SubscriptionProductID.yearly.rawValue,
                        displayName: "Yearly",
                        displayPrice: "$0.99",
                        periodDescription: "Year"
                    )
                ],
                entitlement: .none
            )
            let manager = SubscriptionManager(
                service: service,
                cache: cache,
                userDefaults: defaults,
                widgetReloader: TestWidgetReloader()
            )
            #expect(manager.isPro)
            await manager.start()
            #expect(manager.isPro == false)
            #expect(manager.state.products.count == 1)
        }
    }

    @Test
    @MainActor
    func subscriptionManager_purchaseSuccess_unlocksPro() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let service = FakeSubscriptionService(
                products: [
                    SubscriptionProduct(
                        id: SubscriptionProductID.yearly.rawValue,
                        displayName: "Yearly",
                        displayPrice: "$0.99",
                        periodDescription: "Year"
                    )
                ],
                entitlement: .none,
                purchaseResult: .success,
                entitlementAfterPurchase: TestFixtures.activeEntitlement
            )
            let manager = SubscriptionManager(
                service: service,
                cache: EntitlementCache(userDefaults: defaults),
                userDefaults: defaults,
                widgetReloader: TestWidgetReloader()
            )
            let result = await manager.purchase(productID: SubscriptionProductID.yearly.rawValue)
            #expect(result == .success)
            #expect(manager.isPro)
        }
    }

    @Test
    @MainActor
    func subscriptionManager_emptyProducts_surfacesStoreKitError() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let service = FakeSubscriptionService(products: [], entitlement: .none)
            let manager = SubscriptionManager(
                service: service,
                cache: EntitlementCache(userDefaults: defaults),
                userDefaults: defaults,
                widgetReloader: TestWidgetReloader()
            )
            await manager.refreshProducts()
            #expect(manager.state.products.isEmpty)
            #expect(manager.state.loadState == .error(String(localized: "subscription.error.storekit_empty")))
        }
    }

    @Test
    @MainActor
    func subscriptionManager_keepsCacheWhenVerificationFails() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let cache = EntitlementCache(userDefaults: defaults)
            cache.save(
                EntitlementSnapshot(
                    productID: SubscriptionProductID.monthly.rawValue,
                    expirationDate: Date().addingTimeInterval(86400),
                    isActive: true,
                    source: "storekit",
                    verifiedAt: Date()
                )
            )
            let service = FakeSubscriptionService(products: [], entitlement: .unverified)
            let manager = SubscriptionManager(
                service: service,
                cache: cache,
                userDefaults: defaults,
                widgetReloader: TestWidgetReloader()
            )
            #expect(manager.isPro)
            await manager.start()
            #expect(manager.isPro)
        }
    }

    @Test
    @MainActor
    func subscriptionManager_restoreFailed_keepsCache() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let cache = EntitlementCache(userDefaults: defaults)
            cache.save(TestFixtures.activeEntitlement)
            let service = FakeSubscriptionService(
                products: [],
                entitlement: .unverified,
                restoreEntitlement: .unverified
            )
            let manager = SubscriptionManager(
                service: service,
                cache: cache,
                userDefaults: defaults,
                widgetReloader: TestWidgetReloader()
            )
            let outcome = await manager.restore()
            #expect(outcome == .failed)
            #expect(manager.isPro)
        }
    }

    @Test
    @MainActor
    func subscriptionManager_restoreEmpty_clearsCache() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let cache = EntitlementCache(userDefaults: defaults)
            cache.save(TestFixtures.activeEntitlement)
            let service = FakeSubscriptionService(
                products: [],
                entitlement: .none,
                restoreEntitlement: EntitlementVerification.none
            )
            let manager = SubscriptionManager(
                service: service,
                cache: cache,
                userDefaults: defaults,
                widgetReloader: TestWidgetReloader()
            )
            let outcome = await manager.restore()
            #expect(outcome == .empty)
            #expect(manager.isPro == false)
            #expect(cache.load() == nil)
        }
    }

    @Test
    @MainActor
    func subscriptionManager_purchaseCancelled_doesNotGrantPro() async {
        let service = FakeSubscriptionService(
            products: [],
            entitlement: .none,
            purchaseResult: .cancelled,
            entitlementAfterPurchase: TestFixtures.activeEntitlement
        )
        let manager = SubscriptionManager(
            service: service,
            cache: EntitlementCache(),
            widgetReloader: TestWidgetReloader()
        )
        _ = await manager.purchase(productID: SubscriptionProductID.yearly.rawValue)
        #expect(manager.isPro == false)
    }

    @Test
    @MainActor
    func subscriptionManager_purchasePending_doesNotGrantPro() async {
        let service = FakeSubscriptionService(
            products: [],
            entitlement: .none,
            purchaseResult: .pending,
            entitlementAfterPurchase: TestFixtures.activeEntitlement
        )
        let manager = SubscriptionManager(
            service: service,
            cache: EntitlementCache(),
            widgetReloader: TestWidgetReloader()
        )
        _ = await manager.purchase(productID: SubscriptionProductID.yearly.rawValue)
        #expect(manager.isPro == false)
    }

    @Test
    @MainActor
    func subscriptionManager_purchaseFailed_doesNotGrantPro() async {
        let service = FakeSubscriptionService(
            products: [],
            entitlement: .none,
            purchaseResult: .failed("Payment failed"),
            entitlementAfterPurchase: TestFixtures.activeEntitlement
        )
        let manager = SubscriptionManager(
            service: service,
            cache: EntitlementCache(),
            widgetReloader: TestWidgetReloader()
        )
        _ = await manager.purchase(productID: SubscriptionProductID.yearly.rawValue)
        #expect(manager.isPro == false)
    }

    @Test
    @MainActor
    func entitlementCache_expiredSnapshot_isIgnoredByManagerFilter() {
        TestDefaults.withTemporaryDefaults { defaults in
            let cache = EntitlementCache(userDefaults: defaults)
            cache.save(
                EntitlementSnapshot(
                    productID: SubscriptionProductID.monthly.rawValue,
                    expirationDate: Date().addingTimeInterval(-60),
                    isActive: true,
                    source: "storekit",
                    verifiedAt: Date().addingTimeInterval(-3600)
                )
            )
            let manager = makeManager(
                service: FakeSubscriptionService(products: [], entitlement: .none),
                defaults: defaults
            )
            #expect(manager.isPro == false)
        }
    }
}

private extension SubscriptionTests {
    @MainActor
    func makeManager(
        service: any SubscriptionServicing,
        defaults: UserDefaults
    ) -> SubscriptionManager {
        SubscriptionManager(
            service: service,
            cache: EntitlementCache(userDefaults: defaults),
            userDefaults: defaults,
            widgetReloader: TestWidgetReloader()
        )
    }
}
