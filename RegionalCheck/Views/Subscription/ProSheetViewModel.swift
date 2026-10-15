import Foundation
import Observation

/// What the sheet needs to switch the Pro icon; `ProAppearance` in the app.
@MainActor
protocol ProIconSwitching: AnyObject {
    var usesProIcon: Bool { get }
    func setUsesProIcon(_ isOn: Bool)
}

extension ProAppearance: ProIconSwitching {}

/// The compact Pro sheet (ADR 0016): one cosmetic product, Buy and Restore, and for an owner the
/// Pro icon switch.
@MainActor
@Observable
final class ProSheetViewModel: Identifiable {
    enum Phase: Equatable {
        case loading
        case unavailable
        case offer(price: String)
        case owned
    }

    private let purchases: any PurchaseManaging
    private let icon: any ProIconSwitching

    private(set) var isWorking = false
    /// Catalog key of the line under the buttons; nil when there is nothing to report.
    private(set) var messageKey: String?

    init(purchases: any PurchaseManaging, icon: any ProIconSwitching) {
        self.purchases = purchases
        self.icon = icon
    }

    var phase: Phase {
        if purchases.isPro {
            return .owned
        }
        if let product {
            return .offer(price: product.displayPrice)
        }
        return isLoadingProducts || purchases.state.loadState == .loading ? .loading : .unavailable
    }

    private var isLoadingProducts = false

    var usesProIcon: Bool {
        get { icon.usesProIcon }
        set { icon.setUsesProIcon(newValue) }
    }

    var canManageSubscription: Bool {
        purchases.state.hasSubscriptionEntitlement
    }

    private var product: SubscriptionProduct? {
        purchases.state.products.first { $0.id == SubscriptionProductID.cosmetic.rawValue }
    }

    func load() async {
        guard product == nil, !purchases.isPro else { return }
        isLoadingProducts = true
        await purchases.refreshProducts()
        isLoadingProducts = false
    }

    func buy() async {
        guard !isWorking, let product else { return }
        isWorking = true
        defer { isWorking = false }
        messageKey = nil
        switch await purchases.purchase(productID: product.id) {
        case .success:
            // A purchase StoreKit reports but cannot verify unlocks nothing.
            messageKey = purchases.isPro ? nil : "pro.sheet.failed"
        case .cancelled, .pending:
            break
        case .failed:
            messageKey = "pro.sheet.failed"
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        messageKey =
            switch await purchases.restore() {
            case .restored: "subscription.restore.success"
            case .empty: "subscription.restore.empty"
            case .failed: "subscription.restore.failed"
            }
    }
}
