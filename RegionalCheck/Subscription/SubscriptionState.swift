import Foundation

enum SubscriptionLoadState: Equatable {
    case idle
    case loading
    case ready
    case purchasing
    case error(String)
}

struct SubscriptionState: Equatable {
    var loadState: SubscriptionLoadState = .idle
    var products: [SubscriptionProduct] = []
    var entitlement: EntitlementSnapshot?

    var isPro: Bool {
        entitlement?.isActive == true
    }

    /// True only while Pro rests on an earlier subscription: the one-time purchase has nothing to
    /// manage, so Manage Subscription is offered for this alone.
    var hasSubscriptionEntitlement: Bool {
        guard isPro, let productID = entitlement?.productID else { return false }
        return SubscriptionProductID(rawValue: productID)?.isSubscription == true
    }
}
