import Foundation

@MainActor
protocol PurchaseManaging: AnyObject {
    var state: SubscriptionState { get }
    var isPro: Bool { get }
    func refreshProducts() async
    func purchase(productID: String) async -> PurchaseResult
    func restore() async -> RestoreOutcome
}

@MainActor
protocol FeatureGating {
    func allows(_ feature: PremiumFeature) -> Bool
}

protocol EntitlementPersisting: Sendable {
    func saveIsPro(_ isPro: Bool)
}
