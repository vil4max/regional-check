import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct ProSheetViewModelTests {
    private static let cosmetic = SubscriptionProduct(
        id: SubscriptionProductID.cosmetic.rawValue,
        displayName: "Drive Check Pro",
        displayPrice: "$0.99",
        periodDescription: ""
    )

    private static func entitlement(_ id: SubscriptionProductID) -> EntitlementSnapshot {
        EntitlementSnapshot(
            productID: id.rawValue,
            expirationDate: id.isSubscription ? Date(timeIntervalSince1970: 2_000_000_000) : nil,
            isActive: true,
            source: "storekit",
            verifiedAt: Date(timeIntervalSince1970: 1)
        )
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-1 a driver without Pro is offered the cosmetic product at its price")
    func offerShowsThePrice() {
        let purchases = FakePurchases(products: [Self.cosmetic])
        let sheet = ProSheetViewModel(purchases: purchases, icon: FakeIconSwitch())

        #expect(sheet.phase == .offer(price: "$0.99"))
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-2 a verified purchase shows the owned state")
    func verifiedPurchaseShowsOwned() async {
        let purchases = FakePurchases(products: [Self.cosmetic])
        purchases.entitlementAfterPurchase = Self.entitlement(.cosmetic)
        let sheet = ProSheetViewModel(purchases: purchases, icon: FakeIconSwitch())

        await sheet.buy()

        #expect(sheet.phase == .owned)
        #expect(sheet.messageKey == nil)
        #expect(purchases.purchasedIDs == [SubscriptionProductID.cosmetic.rawValue])
    }

    @Test(
        "REQ-SURF-007 PRO-COSMETIC AC-7 a cancelled or pending purchase leaves the offer without a message",
        arguments: [PurchaseResult.cancelled, .pending]
    )
    func cancelledOrPendingPurchaseStaysQuiet(_ result: PurchaseResult) async {
        let purchases = FakePurchases(products: [Self.cosmetic], purchaseResult: result)
        let sheet = ProSheetViewModel(purchases: purchases, icon: FakeIconSwitch())

        await sheet.buy()

        #expect(sheet.phase == .offer(price: "$0.99"))
        #expect(sheet.messageKey == nil)
    }

    @Test(
        "REQ-SURF-007 PRO-COSMETIC AC-7 a failed or unverified purchase reports a failure and unlocks nothing",
        arguments: [PurchaseResult.failed("boom"), .success]
    )
    func failedPurchaseReportsFailure(_ result: PurchaseResult) async {
        let purchases = FakePurchases(products: [Self.cosmetic], purchaseResult: result)
        let sheet = ProSheetViewModel(purchases: purchases, icon: FakeIconSwitch())

        await sheet.buy()

        #expect(sheet.phase == .offer(price: "$0.99"))
        #expect(sheet.messageKey == "pro.sheet.failed")
    }

    @Test(
        "REQ-SURF-007 PRO-COSMETIC AC-8 restore reports its outcome",
        arguments: [
            (RestoreOutcome.restored, "subscription.restore.success"),
            (.empty, "subscription.restore.empty"),
            (.failed, "subscription.restore.failed"),
        ])
    func restoreReportsOutcome(_ outcome: RestoreOutcome, _ key: String) async {
        let purchases = FakePurchases(products: [Self.cosmetic], restoreOutcome: outcome)
        let sheet = ProSheetViewModel(purchases: purchases, icon: FakeIconSwitch())

        await sheet.restore()

        #expect(sheet.messageKey == key)
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-9 only an earlier subscription can be managed")
    func manageOnlyForSubscription() {
        let owner = FakePurchases(products: [], entitlement: Self.entitlement(.cosmetic))
        let subscriber = FakePurchases(products: [], entitlement: Self.entitlement(.yearly))

        #expect(ProSheetViewModel(purchases: owner, icon: FakeIconSwitch()).canManageSubscription == false)
        #expect(ProSheetViewModel(purchases: subscriber, icon: FakeIconSwitch()).canManageSubscription)
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-3 the sheet's switch drives the Pro icon choice")
    func iconSwitchForwardsTheChoice() {
        let icon = FakeIconSwitch()
        let sheet = ProSheetViewModel(
            purchases: FakePurchases(products: [], entitlement: Self.entitlement(.cosmetic)),
            icon: icon
        )

        sheet.usesProIcon = false

        #expect(icon.usesProIcon == false)
    }

    @Test("REQ-SURF-007 PRO-COSMETIC an empty catalog is unavailable, not a spinner")
    func emptyCatalogIsUnavailable() {
        let sheet = ProSheetViewModel(purchases: FakePurchases(products: []), icon: FakeIconSwitch())

        #expect(sheet.phase == .unavailable)
    }
}

@MainActor
private final class FakePurchases: PurchaseManaging {
    var state: SubscriptionState
    var entitlementAfterPurchase: EntitlementSnapshot?
    private(set) var purchasedIDs: [String] = []
    private let purchaseResult: PurchaseResult
    private let restoreOutcome: RestoreOutcome

    var isPro: Bool {
        state.isPro
    }

    init(
        products: [SubscriptionProduct],
        entitlement: EntitlementSnapshot? = nil,
        purchaseResult: PurchaseResult = .success,
        restoreOutcome: RestoreOutcome = .empty
    ) {
        state = SubscriptionState(loadState: .ready, products: products, entitlement: entitlement)
        self.purchaseResult = purchaseResult
        self.restoreOutcome = restoreOutcome
    }

    func refreshProducts() async {}

    func purchase(productID: String) async -> PurchaseResult {
        purchasedIDs.append(productID)
        if purchaseResult == .success, let entitlementAfterPurchase {
            state.entitlement = entitlementAfterPurchase
        }
        return purchaseResult
    }

    func restore() async -> RestoreOutcome {
        restoreOutcome
    }
}

@MainActor
private final class FakeIconSwitch: ProIconSwitching {
    private(set) var usesProIcon = true

    func setUsesProIcon(_ isOn: Bool) {
        usesProIcon = isOn
    }
}
