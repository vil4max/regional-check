import Foundation
import Observation

@MainActor
@Observable
final class PaywallViewModel {
    /// RD-16: the five paywall states (`docs/design/redesign/screens-onboarding-about-paywall.md`
    /// §3). Error and Empty used to be one `.empty` branch with an optional error message
    /// (behavior change #3); Subscribed is new (behavior change #2).
    enum ContentState: Equatable {
        case subscribed
        case loading
        case error(String)
        case empty
        case plans([SubscriptionProduct])
    }

    private let manager: any PurchaseManaging
    private let syncLiveActivity: () -> Void
    private let onDismiss: () -> Void

    var selectedProductID: String = SubscriptionProductID.yearly.rawValue
    var statusMessage: String?
    var isBusy = false
    private(set) var isLoadingProducts = false

    var products: [SubscriptionProduct] {
        manager.state.products
    }

    var selectedProduct: SubscriptionProduct? {
        products.first(where: { $0.id == selectedProductID }) ?? products.first
    }

    /// Pro (behavior change #1/#2) wins over every other state: a subscriber never sees plans,
    /// loading or an error card just because a later catalog refresh happens to be in flight.
    var contentState: ContentState {
        if isPro {
            return .subscribed
        }
        if isLoadingProducts, products.isEmpty {
            return .loading
        }
        // A stale error from a failed background refresh does not hide plans already on screen.
        if !products.isEmpty {
            return .plans(products)
        }
        if let loadErrorMessage {
            return .error(loadErrorMessage)
        }
        return .empty
    }

    /// Subscribed-state card (behavior change #2): the entitled product's display name when the
    /// catalog is loaded, else a Pro-badge fallback so the card still reads correctly before
    /// `reloadProducts()` returns.
    var subscribedPlanName: String {
        guard let entitlement = manager.state.entitlement else {
            return String(localized: "subscription.badge.pro")
        }
        if let product = products.first(where: { $0.id == entitlement.productID }) {
            return product.displayName
        }
        switch SubscriptionProductID(rawValue: entitlement.productID) {
        case .yearly:
            return String(localized: "subscription.period.year")
        case .monthly:
            return String(localized: "subscription.period.month")
        case nil:
            return String(localized: "subscription.badge.pro")
        }
    }

    var subscribedRenewalText: String {
        guard let expiration = manager.state.entitlement?.expirationDate else {
            return "—"
        }
        return expiration.formatted(date: .abbreviated, time: .omitted)
    }

    var subscribedDetailLine: String {
        String(
            format: String(localized: "subscription.paywall.subscribed.detail %@ %@"),
            subscribedPlanName,
            subscribedRenewalText
        )
    }

    var subscribeTitle: String {
        if let product = selectedProduct {
            String(
                localized: "subscription.paywall.subscribePrice \(product.displayPrice)"
            )
        } else {
            String(localized: "subscription.paywall.subscribe")
        }
    }

    var isPro: Bool {
        manager.isPro
    }

    var loadState: SubscriptionLoadState {
        manager.state.loadState
    }

    var loadErrorMessage: String? {
        if case let .error(message) = loadState {
            return message
        }
        return nil
    }

    init(
        manager: any PurchaseManaging,
        syncLiveActivity: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.manager = manager
        self.syncLiveActivity = syncLiveActivity
        self.onDismiss = onDismiss
        selectPreferredProduct()
    }

    func onAppear() async {
        await reloadProducts()
    }

    func reloadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        await manager.refreshProducts()
        selectPreferredProduct()
    }

    func purchase() async {
        guard let productID = selectedProduct?.id else { return }
        guard !isBusy else { return }
        isBusy = true
        let result = await manager.purchase(productID: productID)
        switch result {
        case .success:
            syncLiveActivity()
            isBusy = false
            onDismiss()
        case .cancelled:
            statusMessage = nil
            isBusy = false
        case .pending:
            statusMessage = String(localized: "subscription.purchase.pending")
        case let .failed(message):
            statusMessage = message
            isBusy = false
        }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let outcome = await manager.restore()
        switch outcome {
        case .restored:
            statusMessage = String(localized: "subscription.restore.success")
            syncLiveActivity()
        case .empty:
            statusMessage = String(localized: "subscription.restore.empty")
        case .failed:
            statusMessage = String(localized: "subscription.restore.failed")
        }
    }

    private func selectPreferredProduct() {
        if let yearly = products.first(where: { $0.id == SubscriptionProductID.yearly.rawValue }) {
            selectedProductID = yearly.id
        } else if let first = products.first {
            selectedProductID = first.id
        }
    }
}
