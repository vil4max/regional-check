#if DEBUG
    import SwiftUI

    #Preview("Paywall") {
        PaywallView(
            manager: AppContainer.fixture().subscription,
            syncLiveActivity: {},
            onDismiss: {}
        )
    }

    #Preview("Paywall Loading") {
        PaywallView(
            manager: PaywallPreviewSubscriptionManager(loadState: .loading, products: []),
            syncLiveActivity: {},
            onDismiss: {}
        )
    }

    #Preview("Paywall Error") {
        PaywallView(
            manager: PaywallPreviewSubscriptionManager(
                loadState: .error("Store unavailable"),
                products: []
            ),
            syncLiveActivity: {},
            onDismiss: {}
        )
    }

    #Preview("Paywall Empty") {
        PaywallView(
            manager: PaywallPreviewSubscriptionManager(loadState: .ready, products: []),
            syncLiveActivity: {},
            onDismiss: {}
        )
    }

    #Preview("Paywall Subscribed") {
        PaywallView(
            manager: PaywallPreviewSubscriptionManager(
                loadState: .ready,
                products: [
                    SubscriptionProduct(
                        id: SubscriptionProductID.yearly.rawValue,
                        displayName: "Drive Check Pro",
                        displayPrice: "$14.99",
                        periodDescription: "year"
                    )
                ],
                entitlement: EntitlementSnapshot(
                    productID: SubscriptionProductID.yearly.rawValue,
                    expirationDate: AppContainer.fixtureNow.addingTimeInterval(220 * 86400),
                    isActive: true,
                    source: "preview",
                    verifiedAt: AppContainer.fixtureNow
                )
            ),
            syncLiveActivity: {},
            onDismiss: {}
        )
    }

    /// Fixed states `AppContainer.fixture()` doesn't parameterize (it always resolves a settled
    /// `.ready` catalog) — one state per `PaywallViewModel.ContentState`, matching the mockups
    /// `paywall-{plans,loading,error,empty,subscribed}.png`. Not `private`: the Prefire-generated
    /// `PreviewTests.generated.swift` lives in the test target and reaches this only via
    /// `@testable import RegionalCheck`, which cannot see file-private declarations.
    @MainActor
    final class PaywallPreviewSubscriptionManager: SubscriptionManaging {
        var state: SubscriptionState
        var isPro: Bool {
            state.isPro
        }

        init(
            loadState: SubscriptionLoadState,
            products: [SubscriptionProduct],
            entitlement: EntitlementSnapshot? = nil
        ) {
            state = SubscriptionState(loadState: loadState, products: products, entitlement: entitlement)
        }

        func start() async {}
        func refreshProducts() async {}
        func purchase(productID _: String) async -> PurchaseResult {
            .cancelled
        }

        func restore() async -> RestoreOutcome {
            .empty
        }

        func allows(_: PremiumFeature) -> Bool {
            isPro
        }

        func setLiveActivityEnabled(_ enabled: Bool) {
            state.isLiveActivityEnabled = enabled
        }

        func entitlementChanges() -> AsyncStream<Void> {
            AsyncStream { $0.finish() }
        }
    }
#endif
