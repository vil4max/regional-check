import Foundation

@MainActor
protocol SubscriptionManaging: AnyObject {
    var state: SubscriptionState { get }
    var isPro: Bool { get }
    func start() async
    func refreshProducts() async
    func purchase(productID: String) async -> PurchaseResult
    func restore() async -> RestoreOutcome
    func allows(_ feature: PremiumFeature) -> Bool
    func setLiveActivityEnabled(_ enabled: Bool)
    func entitlementChanges() -> AsyncStream<Void>
}

protocol EntitlementPersisting: Sendable {
    func saveIsPro(_ isPro: Bool)
}
