import Foundation

/// What one verified StoreKit transaction says about Pro, reduced to plain values so the selection
/// rule can be tested without StoreKit.
struct EntitlementFact: Equatable, Sendable {
    let productID: String
    let expirationDate: Date?
    let isRevoked: Bool
}

enum EntitlementSelection {
    /// The entitlement Pro rests on, or nil. Only known products count. A purchase without an
    /// expiry (the one-time cosmetic bundle) is permanent until revoked and wins over a
    /// subscription; between subscriptions the later expiry wins.
    static func best(from facts: [EntitlementFact], now: Date) -> EntitlementSnapshot? {
        let active = facts.filter { fact in
            guard SubscriptionProductID(rawValue: fact.productID) != nil, !fact.isRevoked else { return false }
            guard let expiration = fact.expirationDate else { return true }
            return expiration > now
        }
        let winner = active.max { lhs, rhs in
            (lhs.expirationDate ?? .distantFuture) < (rhs.expirationDate ?? .distantFuture)
        }
        return winner.map {
            EntitlementSnapshot(
                productID: $0.productID,
                expirationDate: $0.expirationDate,
                isActive: true,
                source: "storekit",
                verifiedAt: now
            )
        }
    }
}
