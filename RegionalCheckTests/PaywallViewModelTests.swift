import Foundation
@testable import RegionalCheck
import Testing

struct PaywallViewModelTests {
    @Test
    @MainActor
    func purchaseSuccess_callsDismissAndSync() async {
        var didSync = false
        var didDismiss = false
        let manager = FakeSubscriptionManager(
            purchaseResult: .success,
            entitlementAfterPurchase: EntitlementSnapshot(
                productID: SubscriptionProductID.yearly.rawValue,
                expirationDate: Date().addingTimeInterval(86400),
                isActive: true,
                source: "storekit",
                verifiedAt: Date()
            )
        )
        let viewModel = PaywallViewModel(
            manager: manager,
            syncLiveActivity: { didSync = true },
            onDismiss: { didDismiss = true }
        )
        await viewModel.purchase()
        #expect(didSync)
        #expect(didDismiss)
        #expect(viewModel.isBusy == false)
    }

    @Test
    @MainActor
    func purchasePending_keepsBusy() async {
        let manager = FakeSubscriptionManager(purchaseResult: .pending)
        let viewModel = PaywallViewModel(manager: manager)
        await viewModel.purchase()
        #expect(viewModel.isBusy)
        #expect(viewModel.statusMessage == String(localized: "subscription.purchase.pending"))
    }

    @Test
    @MainActor
    func restoreFailed_showsDistinctMessage() async {
        let manager = FakeSubscriptionManager(restoreOutcome: .failed)
        let viewModel = PaywallViewModel(manager: manager)
        await viewModel.restore()
        #expect(viewModel.statusMessage == String(localized: "subscription.restore.failed"))
    }

    @Test
    @MainActor
    func loadErrorMessage_surfacesStoreError() {
        let manager = FakeSubscriptionManager(loadState: .error("Store unavailable"))
        let viewModel = PaywallViewModel(manager: manager)
        #expect(viewModel.loadErrorMessage == "Store unavailable")
    }

    @Test
    @MainActor
    func storeStatus_surfacesAccessAndCatalog() {
        let manager = FakeSubscriptionManager()
        let viewModel = PaywallViewModel(manager: manager)
        #expect(viewModel.accessStatusLine == String(localized: "subscription.status.access.free"))
        #expect(viewModel.storeKitStatusLine == String(
            format: String(localized: "subscription.status.storekit.ready %lld"),
            Int64(1)
        ))
        #expect(viewModel.catalogSourceLine == String(localized: "subscription.status.storekit.live"))
        #expect(viewModel.entitlementStatusLine == String(localized: "subscription.status.entitlement.none"))
    }

    @Test
    @MainActor
    func storeStatus_emptyCatalog_showsUnavailableHint() {
        let manager = FakeSubscriptionManager(loadState: .error("empty"), products: [])
        let viewModel = PaywallViewModel(manager: manager)
        #expect(viewModel.storeKitStatusLine == String(localized: "subscription.status.storekit.empty"))
        #expect(viewModel.catalogSourceLine == String(localized: "subscription.status.storekit.hint"))
    }
}

@MainActor
private final class FakeSubscriptionManager: SubscriptionManaging {
    var state: SubscriptionState
    var isPro: Bool {
        state.isPro
    }

    private let purchaseResult: PurchaseResult
    private let restoreOutcome: RestoreOutcome

    init(
        purchaseResult: PurchaseResult = .cancelled,
        entitlementAfterPurchase: EntitlementSnapshot? = nil,
        restoreOutcome: RestoreOutcome = .empty,
        loadState: SubscriptionLoadState = .ready,
        products: [SubscriptionProduct]? = nil
    ) {
        self.purchaseResult = purchaseResult
        self.restoreOutcome = restoreOutcome
        state = SubscriptionState(loadState: loadState)
        state.products = products ?? [
            SubscriptionProduct(
                id: SubscriptionProductID.yearly.rawValue,
                displayName: "Yearly",
                displayPrice: "$0.99",
                periodDescription: "Year"
            )
        ]
        if let entitlementAfterPurchase {
            state.entitlement = entitlementAfterPurchase
        }
    }

    func start() async {}

    func refreshProducts() async {}

    func purchase(productID _: String) async -> PurchaseResult {
        purchaseResult
    }

    func restore() async -> RestoreOutcome {
        restoreOutcome
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
