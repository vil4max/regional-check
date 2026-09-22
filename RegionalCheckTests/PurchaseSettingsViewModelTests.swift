import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct PurchaseSettingsViewModelTests {
    @Test(
        "REQ-SURF-007 each restore outcome is reported with its own message",
        arguments: [
            (RestoreOutcome.restored, "subscription.restore.success"),
            (RestoreOutcome.empty, "subscription.restore.empty"),
            (RestoreOutcome.failed, "subscription.restore.failed"),
        ]
    )
    func restoreOutcomeMapsToItsMessage(outcome: RestoreOutcome, key: String) async {
        let sut = PurchaseSettingsViewModel(purchases: PurchaseRestoringFake(outcome: outcome))
        #expect(sut.restoreMessageKey == nil)

        await sut.restore()

        #expect(sut.restoreStatus == .finished(outcome))
        #expect(sut.restoreMessageKey == key)
        #expect(sut.isRestoring == false)
    }

    @Test("REQ-SURF-007 Manage Subscription is offered only while an entitlement is active")
    func manageSubscriptionFollowsTheEntitlement() async {
        let purchases = PurchaseRestoringFake(outcome: .restored, isProAfterRestore: true)
        let sut = PurchaseSettingsViewModel(purchases: purchases)
        #expect(sut.canManageSubscription == false)

        await sut.restore()

        #expect(sut.canManageSubscription)
    }

    @Test("REQ-SURF-007 a second tap while a restore is running does not start another one")
    func restoreDoesNotReenter() async {
        let purchases = PurchaseRestoringFake(outcome: .empty)
        let sut = PurchaseSettingsViewModel(purchases: purchases)
        purchases.onRestore = { await sut.restore() }

        await sut.restore()

        #expect(purchases.restoreCalls == 1)
    }

    /// Reads the source catalog rather than the app bundle, as `AboutDisclaimerTests` does: the
    /// catalog is where a key can be checked in every shipped locale at once.
    @Test("REQ-SURF-007 the Purchases section's strings exist in English, Ukrainian and Russian")
    func purchasesStringsAreLocalizedEverywhere() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("RegionalCheck/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any]
        let strings = try #require(json?["strings"] as? [String: Any])
        let keys = [
            "about.section.purchases",
            "about.section.liveActivity",
            "subscription.paywall.restore",
            "subscription.paywall.manage",
            "subscription.restore.success",
            "subscription.restore.empty",
            "subscription.restore.failed",
        ]

        for key in keys {
            let entry = try #require(strings[key] as? [String: Any], "\(key) missing from the catalog")
            let localizations = try #require(entry["localizations"] as? [String: Any])
            for locale in ["en", "uk", "ru"] {
                let unit = (localizations[locale] as? [String: Any])?["stringUnit"] as? [String: Any]
                let value = unit?["value"] as? String
                #expect(value?.isEmpty == false, "\(key) missing for \(locale)")
            }
        }
    }
}

@MainActor
private final class PurchaseRestoringFake: PurchaseRestoring {
    private(set) var isPro = false
    private(set) var restoreCalls = 0
    var onRestore: (() async -> Void)?
    private let outcome: RestoreOutcome
    private let isProAfterRestore: Bool

    init(outcome: RestoreOutcome, isProAfterRestore: Bool = false) {
        self.outcome = outcome
        self.isProAfterRestore = isProAfterRestore
    }

    func restore() async -> RestoreOutcome {
        restoreCalls += 1
        await onRestore?()
        isPro = isProAfterRestore
        return outcome
    }
}
