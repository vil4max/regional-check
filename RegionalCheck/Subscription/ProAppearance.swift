import Foundation
import Observation

/// What the Pro decoration needs from the purchase layer.
@MainActor
protocol ProOwnershipSource: AnyObject {
    var isPro: Bool { get }
    func entitlementChanges() -> AsyncStream<Void>
}

extension SubscriptionManager: ProOwnershipSource {}

/// The cosmetic side of Pro (ADR 0016): whether the driver owns it, and whether an owner wants the
/// Pro app icon. Applies the icon whenever either changes; losing Pro restores the primary icon.
@MainActor
@Observable
final class ProAppearance {
    static let usesProIconKey = "pro.usesProIcon"

    /// Whether Pro is on sale. Off until its In-App Purchase exists in App Store Connect (owner,
    /// 2026-10-20): a purchase screen with no product to buy is an App Review rejection.
    static let isOffered = false

    /// Whether the crown and the Details row lead to the Pro sheet. An owner always keeps them,
    /// because the sheet holds the Pro icon switch.
    var showsEntry: Bool {
        Self.isOffered || isOwner
    }

    private(set) var usesProIcon: Bool

    /// Read through, not cached, so the decoration is right from the first frame: the purchase
    /// layer already knows an owner from its offline cache before StoreKit answers.
    var isOwner: Bool {
        ownership.isPro
    }

    private let ownership: any ProOwnershipSource
    private let defaults: UserDefaults
    private let iconPresenter: (any AlternateIconPresenting)?
    private var observation: Task<Void, Never>?

    /// `iconPresenter` nil means the app itself, which unit tests never reach.
    init(
        ownership: any ProOwnershipSource,
        defaults: UserDefaults,
        iconPresenter: (any AlternateIconPresenting)?
    ) {
        self.ownership = ownership
        self.defaults = defaults
        self.iconPresenter = iconPresenter
        usesProIcon = defaults.object(forKey: Self.usesProIconKey) as? Bool ?? true
    }

    isolated deinit {
        observation?.cancel()
    }

    /// Applies the current state, then follows entitlement changes for the app's lifetime.
    func start() {
        applyIcon()
        observation?.cancel()
        let changes = ownership.entitlementChanges()
        observation = Task { [weak self] in
            for await _ in changes {
                self?.applyIcon()
            }
        }
    }

    func setUsesProIcon(_ isOn: Bool) {
        usesProIcon = isOn
        defaults.set(isOn, forKey: Self.usesProIconKey)
        applyIcon()
    }

    private func applyIcon() {
        AlternateIconManager.sync(isPro: isOwner && usesProIcon, presenter: iconPresenter)
    }
}
