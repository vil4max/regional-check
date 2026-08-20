import Foundation
import os
import StoreKit

struct StoreKitSubscriptionService: SubscriptionServicing {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Subscription")

    private let updates: @Sendable () -> AsyncStream<FinishableTransactionUpdate>
    private let entitlements: @Sendable () async -> EntitlementVerification
    private let syncPurchases: @Sendable () async throws -> Void

    init(
        updates: @escaping @Sendable () -> AsyncStream<FinishableTransactionUpdate> = {
            StoreKitSubscriptionService.liveUpdates()
        },
        entitlements: (@Sendable () async -> EntitlementVerification)? = nil,
        syncPurchases: @escaping @Sendable () async throws -> Void = {
            try await AppStore.sync()
        }
    ) {
        self.updates = updates
        self.entitlements = entitlements ?? {
            await StoreKitSubscriptionService.verifyEntitlements()
        }
        self.syncPurchases = syncPurchases
    }
}

extension StoreKitSubscriptionService {
    func loadProducts() async throws -> [SubscriptionProduct] {
        let requested = SubscriptionProductID.allRawValues
        let storefront = await Storefront.current?.countryCode ?? "nil"
        #if targetEnvironment(simulator)
            let runtime = "simulator"
        #else
            let runtime = "device"
        #endif
        Self.log.info(
            """
            loadProducts start runtime=\(runtime, privacy: .public) \
            storefront=\(storefront, privacy: .public) \
            requested=\(requested.joined(separator: ","), privacy: .public)
            """
        )
        do {
            let storeProducts = try await Product.products(for: requested)
            let returnedIDs = storeProducts.map(\.id).joined(separator: ",")
            Self.log.info(
                "loadProducts done count=\(storeProducts.count, privacy: .public) ids=\(returnedIDs, privacy: .public)"
            )
            if storeProducts.isEmpty {
                Self.log.error(
                    """
                    loadProducts empty — StoreKit Configuration not injected or ASC catalog missing. \
                    Check Scheme → Run → Options → StoreKit Configuration = Products.storekit, \
                    uncheck custom working directory, delete the app, relaunch from Xcode. \
                    Prefer Simulator for local .storekit testing.
                    """
                )
            }
            return storeProducts
                .sorted { lhs, rhs in
                    sortRank(lhs.id) < sortRank(rhs.id)
                }
                .map(mapProduct)
        } catch {
            Self.log.error("loadProducts failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func purchase(productID: String) async -> PurchaseResult {
        Self.log.info("purchase start productID=\(productID, privacy: .public)")
        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                Self.log.error("purchase missing productID=\(productID, privacy: .public)")
                return .failed(
                    String(
                        format: String(localized: "subscription.error.product_missing %@"),
                        productID
                    )
                )
            }
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                switch verification {
                case let .verified(transaction):
                    Self.log.info(
                        "purchase verified productID=\(transaction.productID, privacy: .public)"
                    )
                    return await StoreKitPurchaseVerification.handleSuccess(
                        isVerified: true,
                        finish: { await transaction.finish() }
                    )
                case let .unverified(transaction, error):
                    Self.log.error(
                        """
                        purchase unverified productID=\(transaction.productID, privacy: .public) \
                        error=\(String(describing: error), privacy: .public)
                        """
                    )
                    return await StoreKitPurchaseVerification.handleSuccess(
                        isVerified: false,
                        finish: { await transaction.finish() }
                    )
                }
            case .userCancelled:
                Self.log.info("purchase cancelled productID=\(productID, privacy: .public)")
                return .cancelled
            case .pending:
                Self.log.info("purchase pending productID=\(productID, privacy: .public)")
                return .pending
            @unknown default:
                Self.log.error("purchase unknown result productID=\(productID, privacy: .public)")
                return .failed(String(localized: "subscription.error.unavailable"))
            }
        } catch {
            let errorDescription = error.localizedDescription
            Self.log.error(
                """
                purchase failed productID=\(productID, privacy: .public) \
                error=\(errorDescription, privacy: .public)
                """
            )
            return .failed(error.localizedDescription)
        }
    }

    func currentEntitlement() async -> EntitlementVerification {
        let verification = await entitlements()
        logEntitlement("currentEntitlement", verification)
        return verification
    }

    func restore() async -> EntitlementVerification {
        Self.log.info("restore start")
        do {
            try await syncPurchases()
            Self.log.info("restore AppStore.sync finished")
        } catch {
            Self.log.error("restore AppStore.sync failed: \(error.localizedDescription, privacy: .public)")
            return .unverified
        }
        let verification = await entitlements()
        logEntitlement("restore", verification)
        return verification
    }

    func listenForUpdates() -> AsyncStream<EntitlementVerification> {
        AsyncStream { continuation in
            let task = Task {
                Self.log.info("Transaction.updates listener started")
                for await update in updates() {
                    Self.log.info(
                        """
                        Transaction.updates productID=\(update.productID, privacy: .public) \
                        verified=\(update.isVerified, privacy: .public)
                        """
                    )
                    await update.finish()
                    await continuation.yield(entitlements())
                }
                Self.log.info("Transaction.updates listener finished")
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func liveUpdates() -> AsyncStream<FinishableTransactionUpdate> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    switch result {
                    case let .verified(transaction):
                        continuation.yield(
                            FinishableTransactionUpdate(
                                productID: transaction.productID,
                                isVerified: true,
                                finish: { await transaction.finish() }
                            )
                        )
                    case let .unverified(transaction, _):
                        continuation.yield(
                            FinishableTransactionUpdate(
                                productID: transaction.productID,
                                isVerified: false,
                                finish: { await transaction.finish() }
                            )
                        )
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func verifyEntitlements() async -> EntitlementVerification {
        var best: EntitlementSnapshot?
        var sawUnverified = false
        var verifiedCount = 0
        for await result in Transaction.currentEntitlements {
            switch result {
            case let .verified(transaction):
                verifiedCount += 1
                guard SubscriptionProductID(rawValue: transaction.productID) != nil else {
                    log.debug(
                        "entitlement skip unknown productID=\(transaction.productID, privacy: .public)"
                    )
                    continue
                }
                let expiration = transaction.expirationDate
                let active: Bool = if let expiration {
                    expiration > Date()
                } else {
                    transaction.revocationDate == nil
                }
                let candidate = EntitlementSnapshot(
                    productID: transaction.productID,
                    expirationDate: expiration,
                    isActive: active && transaction.revocationDate == nil,
                    source: "storekit",
                    verifiedAt: Date()
                )
                if candidate.isActive {
                    if let current = best {
                        let currentExp = current.expirationDate ?? .distantPast
                        let nextExp = candidate.expirationDate ?? .distantPast
                        if nextExp >= currentExp {
                            best = candidate
                        }
                    } else {
                        best = candidate
                    }
                }
            case .unverified:
                sawUnverified = true
            }
        }
        log.info(
            """
            verifyEntitlements verifiedCount=\(verifiedCount, privacy: .public) \
            sawUnverified=\(sawUnverified, privacy: .public) \
            activeProduct=\(best?.productID ?? "none", privacy: .public)
            """
        )
        if let best, best.isActive {
            return .active(best)
        }
        if sawUnverified {
            return .unverified
        }
        return .none
    }

    private func mapProduct(_ product: Product) -> SubscriptionProduct {
        let period: String = if let subscription = product.subscription {
            switch subscription.subscriptionPeriod.unit {
            case .year:
                String(localized: "subscription.period.year")
            case .month:
                String(localized: "subscription.period.month")
            case .week:
                String(localized: "subscription.period.week")
            case .day:
                String(localized: "subscription.period.day")
            @unknown default:
                product.description
            }
        } else {
            product.description
        }
        return SubscriptionProduct(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            periodDescription: period
        )
    }

    private func sortRank(_ id: String) -> Int {
        switch SubscriptionProductID(rawValue: id) {
        case .yearly:
            0
        case .monthly:
            1
        case nil:
            2
        }
    }

    private func logEntitlement(_ label: String, _ verification: EntitlementVerification) {
        switch verification {
        case let .active(snapshot):
            Self.log.info(
                """
                \(label, privacy: .public) active productID=\(snapshot.productID, privacy: .public) \
                source=\(snapshot.source, privacy: .public)
                """
            )
        case .none:
            Self.log.info("\(label, privacy: .public) none")
        case .unverified:
            Self.log.error("\(label, privacy: .public) unverified")
        }
    }
}
