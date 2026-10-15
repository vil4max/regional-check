import Foundation
import Observation

/// What the About screen's Purchases section needs from the subscription layer. Narrower than
/// `PurchaseManaging` on purpose: the section can neither load products nor purchase.
@MainActor
protocol PurchaseRestoring: AnyObject {
    /// True only while Pro rests on an earlier subscription, the one thing there is to manage.
    var hasSubscriptionEntitlement: Bool { get }
    func restore() async -> RestoreOutcome
}

extension SubscriptionManager: PurchaseRestoring {
    var hasSubscriptionEntitlement: Bool {
        state.hasSubscriptionEntitlement
    }
}

/// Restore Purchases and Manage Subscription stay in Details next to the Pro row, so a driver
/// finds them without opening the Pro sheet (REQ-SURF-007).
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

    /// The one-time purchase has nothing to manage, so the row is offered only to a subscriber.
    var canManageSubscription: Bool {
        purchases.hasSubscriptionEntitlement
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
