import DriveCheckKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class SubscriptionManager: SubscriptionManaging {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Subscription")

    private(set) var state = SubscriptionState()

    private let service: any SubscriptionServicing
    private let cache: any EntitlementCaching
    private let userDefaults: UserDefaults
    private let liveActivityPreferenceKey = "subscription.liveActivity.enabled"
    private var updatesTask: Task<Void, Never>?
    private var entitlementChangeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    var isPro: Bool {
        state.isPro
    }

    init(
        service: any SubscriptionServicing = StoreKitSubscriptionService(),
        cache: any EntitlementCaching = EntitlementCache(),
        userDefaults: UserDefaults = .standard
    ) {
        self.service = service
        self.cache = cache
        self.userDefaults = userDefaults
        if let cached = cache.load() {
            state.entitlement = Self.cachedEntitlementIfValid(cached)
        }
        state.isLiveActivityEnabled = userDefaults.object(forKey: liveActivityPreferenceKey) as? Bool ?? true
    }

    func start() async {
        let startIsPro = isPro
        Self.log.info("manager.start begin isPro=\(startIsPro, privacy: .public)")
        applyCachedEntitlement()
        state.loadState = .loading
        await apply(service.currentEntitlement())
        await refreshProducts()
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await verification in service.listenForUpdates() {
                await MainActor.run {
                    self.apply(verification)
                }
            }
        }
        let doneIsPro = isPro
        let productCount = state.products.count
        let loadStateDescription = String(describing: state.loadState)
        Self.log.info(
            """
            manager.start done isPro=\(doneIsPro, privacy: .public) \
            products=\(productCount, privacy: .public) \
            loadState=\(loadStateDescription, privacy: .public)
            """
        )
    }

    func refreshProducts() async {
        Self.log.info("manager.refreshProducts begin")
        do {
            let products = try await service.loadProducts()
            state.products = products
            if state.loadState == .purchasing {
                Self.log.info("manager.refreshProducts skip state while purchasing")
                return
            }
            if products.isEmpty {
                state.loadState = .error(String(localized: "subscription.error.storekit_empty"))
                Self.log.error("manager.refreshProducts empty catalog")
            } else {
                state.loadState = .ready
                Self.log.info("manager.refreshProducts ready count=\(products.count, privacy: .public)")
            }
        } catch {
            state.products = []
            state.loadState = .error(error.localizedDescription)
            Self.log.error(
                "manager.refreshProducts error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func purchase(productID: String) async -> PurchaseResult {
        Self.log.info("manager.purchase begin productID=\(productID, privacy: .public)")
        state.loadState = .purchasing
        let result = await service.purchase(productID: productID)
        await apply(service.currentEntitlement())
        state.loadState = .ready
        let purchaseIsPro = isPro
        let resultDescription = String(describing: result)
        Self.log.info(
            """
            manager.purchase done result=\(resultDescription, privacy: .public) \
            isPro=\(purchaseIsPro, privacy: .public)
            """
        )
        return result
    }

    func restore() async -> RestoreOutcome {
        Self.log.info("manager.restore begin")
        state.loadState = .loading
        let verification = await service.restore()
        switch verification {
        case .active:
            apply(verification)
            state.loadState = .ready
            let restoreIsPro = isPro
            Self.log.info("manager.restore restored isPro=\(restoreIsPro, privacy: .public)")
            return .restored
        case .none:
            apply(verification)
            state.loadState = .ready
            Self.log.info("manager.restore empty")
            return .empty
        case .unverified:
            state.loadState = .ready
            Self.log.error("manager.restore failed unverified")
            return .failed
        }
    }

    func allows(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .proBadge, .extendedDetail:
            isPro
        case .liveActivity:
            isPro && state.isLiveActivityEnabled
        }
    }

    func setLiveActivityEnabled(_ enabled: Bool) {
        let previous = state.isLiveActivityEnabled
        state.isLiveActivityEnabled = enabled
        userDefaults.set(enabled, forKey: liveActivityPreferenceKey)
        if previous != enabled {
            notifyEntitlementChange()
        }
    }

    func entitlementChanges() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            entitlementChangeContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.entitlementChangeContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func notifyEntitlementChange() {
        for continuation in entitlementChangeContinuations.values {
            continuation.yield()
        }
    }

    private func applyCachedEntitlement() {
        guard let cached = cache.load() else { return }
        state.entitlement = Self.cachedEntitlementIfValid(cached)
    }

    private func apply(_ verification: EntitlementVerification) {
        let wasPro = isPro
        let wasLiveActivityEnabled = state.isLiveActivityEnabled
        switch verification {
        case let .active(snapshot):
            state.entitlement = snapshot
            cache.save(snapshot)
        case .none:
            state.entitlement = nil
            cache.clear()
        case .unverified:
            break
        }
        if isPro != wasPro || state.isLiveActivityEnabled != wasLiveActivityEnabled {
            SharedStore.shared.saveIsPro(isPro)
            AlternateIconManager.sync(isPro: isPro)
            WidgetReloader.reloadAllTimelines()
            notifyEntitlementChange()
        }
    }

    private static func cachedEntitlementIfValid(_ snapshot: EntitlementSnapshot) -> EntitlementSnapshot? {
        guard snapshot.isActive else { return nil }
        if let expiration = snapshot.expirationDate, expiration <= Date() {
            return nil
        }
        return snapshot
    }
}
