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
}
