import Foundation
@testable import RegionalCheck
import Testing

struct EntitlementSelectionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func fact(
        _ id: SubscriptionProductID?,
        expires: TimeInterval? = nil,
        revoked: Bool = false
    ) -> EntitlementFact {
        EntitlementFact(
            productID: id?.rawValue ?? "unknown.product",
            expirationDate: expires.map { now.addingTimeInterval($0) },
            isRevoked: revoked
        )
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-5 the one-time cosmetic purchase is an active entitlement")
    func cosmeticPurchaseIsActive() {
        let best = EntitlementSelection.best(from: [fact(.cosmetic)], now: now)

        #expect(best?.productID == SubscriptionProductID.cosmetic.rawValue)
        #expect(best?.isActive == true)
        #expect(best?.expirationDate == nil)
    }

    @Test("REQ-SURF-004 PRO-COSMETIC AC-4 a revoked cosmetic purchase is not an entitlement")
    func revokedCosmeticPurchaseIsNotActive() {
        #expect(EntitlementSelection.best(from: [fact(.cosmetic, revoked: true)], now: now) == nil)
    }

    @Test(
        "REQ-SURF-007 PRO-COSMETIC AC-5 an active earlier subscription still counts",
        arguments: [
            SubscriptionProductID.monthly, .yearly,
        ])
    func activeEarlierSubscriptionCounts(_ id: SubscriptionProductID) {
        #expect(EntitlementSelection.best(from: [fact(id, expires: 3600)], now: now)?.productID == id.rawValue)
    }

    @Test("REQ-SURF-004 PRO-COSMETIC AC-4 an expired or revoked subscription is not an entitlement")
    func expiredOrRevokedSubscriptionIsNotActive() {
        let facts = [fact(.yearly, expires: -1), fact(.monthly, expires: 3600, revoked: true)]

        #expect(EntitlementSelection.best(from: facts, now: now) == nil)
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-9 only a subscription entitlement has something to manage")
    func onlySubscriptionEntitlementIsManageable() {
        let cosmetic = SubscriptionState(entitlement: EntitlementSelection.best(from: [fact(.cosmetic)], now: now))
        let yearly = SubscriptionState(
            entitlement: EntitlementSelection.best(from: [fact(.yearly, expires: 60)], now: now))

        #expect(cosmetic.isPro && !cosmetic.hasSubscriptionEntitlement)
        #expect(yearly.hasSubscriptionEntitlement)
        #expect(!SubscriptionState().hasSubscriptionEntitlement)
    }

    @Test("REQ-SURF-007 PRO-COSMETIC unknown products never grant Pro")
    func unknownProductIsIgnored() {
        #expect(EntitlementSelection.best(from: [fact(nil)], now: now) == nil)
    }

    @Test("REQ-SURF-007 PRO-COSMETIC the permanent purchase wins over an expiring subscription")
    func permanentPurchaseWinsOverSubscription() {
        let facts = [fact(.yearly, expires: 3600), fact(.cosmetic), fact(.monthly, expires: 7200)]

        #expect(EntitlementSelection.best(from: facts, now: now)?.productID == SubscriptionProductID.cosmetic.rawValue)
    }

    @Test("REQ-SURF-007 PRO-COSMETIC between subscriptions the later expiry wins")
    func laterExpiryWinsBetweenSubscriptions() {
        let facts = [fact(.monthly, expires: 7200), fact(.yearly, expires: 3600)]

        #expect(EntitlementSelection.best(from: facts, now: now)?.productID == SubscriptionProductID.monthly.rawValue)
    }
}
