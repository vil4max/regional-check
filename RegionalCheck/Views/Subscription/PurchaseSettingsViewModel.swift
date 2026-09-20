import Foundation
import Observation

/// What the About screen's Purchases section needs from the subscription layer. Narrower than
/// `SubscriptionManaging` on purpose: the section can neither load products nor purchase.
@MainActor
protocol PurchaseRestoring: AnyObject {
    var isPro: Bool { get }
    func restore() async -> RestoreOutcome
}

extension SubscriptionManager: PurchaseRestoring {}

/// REQ-SURF-007 / ADR 0014: Restore Purchases and Manage Subscription lived only inside the
/// paywall, which is no longer presented. This keeps both reachable without it, which is also
/// what keeps live products with no in-app storefront defensible in App Review.
@MainActor
@Observable
final class PurchaseSettingsViewModel {
    enum RestoreStatus: Equatable {
        case idle
        case restoring
        case finished(RestoreOutcome)
    }

    private let purchases: any PurchaseRestoring

    private(set) var restoreStatus: RestoreStatus = .idle

    init(purchases: any PurchaseRestoring) {
        self.purchases = purchases
    }

    /// Manage Subscription has nothing to manage without an entitlement, so it is offered only
    /// to a subscriber — the rule the paywall's subscribed state already followed.
    var canManageSubscription: Bool {
        purchases.isPro
    }

    var isRestoring: Bool {
        restoreStatus == .restoring
    }

    /// Catalog key of the line under the Restore row; nil until a restore has finished.
    var restoreMessageKey: String? {
        switch restoreStatus {
        case .idle, .restoring:
            nil
        case .finished(.restored):
            "subscription.restore.success"
        case .finished(.empty):
            "subscription.restore.empty"
        case .finished(.failed):
            "subscription.restore.failed"
        }
    }

    func restore() async {
        guard !isRestoring else { return }
        restoreStatus = .restoring
        restoreStatus = await .finished(purchases.restore())
    }
}
