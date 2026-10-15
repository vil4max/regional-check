import Foundation

/// The one-time cosmetic bundle is what the app sells (ADR 0016). The two earlier subscriptions
/// stay recognised so a driver who bought one keeps Pro while it is active.
enum SubscriptionProductID: String, CaseIterable {
    case cosmetic = "regioncheck.pro.cosmetic"
    case monthly = "regioncheck.pro.monthly"
    case yearly = "regioncheck.pro.yearly"

    static var allRawValues: [String] {
        allCases.map(\.rawValue)
    }

    var isSubscription: Bool {
        self != .cosmetic
    }
}
