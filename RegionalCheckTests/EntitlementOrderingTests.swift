import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct EntitlementOrderingTests {
    @Test("REQ-SURF-004 a launch-time read that finishes late does not undo a newer revocation")
    func lateLaunchReadDoesNotOverwriteANewerUpdate() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let service = GatedReadService()
            // An owner from the cache, so the revocation below visibly lands before the read ends.
            let cache = EntitlementCache(userDefaults: defaults)
            cache.save(TestFixtures.activeEntitlement)
            let manager = SubscriptionManager(service: service, cache: cache, defaults: defaults)

            let start = Task { await manager.start() }
            await service.waitForRead()
            service.push(.none)
            await service.waitForPushDelivered(to: manager)
            service.finishRead(with: .active(TestFixtures.activeEntitlement))
            await start.value

            #expect(manager.isPro == false)
        }
    }
}

/// `currentEntitlement()` waits until the test answers it, so an update can land in between.
private final class GatedReadService: SubscriptionServicing {
    private let state = Mutex(State())

    private struct State {
        var readContinuation: CheckedContinuation<EntitlementVerification, Never>?
        var readWaiter: CheckedContinuation<Void, Never>?
        var updates: AsyncStream<EntitlementVerification>.Continuation?
    }

    func loadProducts() async throws -> [SubscriptionProduct] { [] }
    func purchase(productID _: String) async -> PurchaseResult { .cancelled }
    func restore() async -> EntitlementVerification { .none }

    func listenForUpdates() -> AsyncStream<EntitlementVerification> {
        AsyncStream { continuation in state.withLock { $0.updates = continuation } }
    }

    func currentEntitlement() async -> EntitlementVerification {
        await withCheckedContinuation { continuation in
            let waiter = state.withLock { state in
                state.readContinuation = continuation
                defer { state.readWaiter = nil }
                return state.readWaiter
            }
            waiter?.resume()
        }
    }

    func waitForRead() async {
        await withCheckedContinuation { continuation in
            let isReading = state.withLock { state in
                if state.readContinuation != nil { return true }
                state.readWaiter = continuation
                return false
            }
            if isReading { continuation.resume() }
        }
    }

    func push(_ verification: EntitlementVerification) {
        _ = state.withLock { $0.updates }?.yield(verification)
    }

    @MainActor
    func waitForPushDelivered(to manager: SubscriptionManager) async {
        for _ in 0..<200 where manager.isPro {
            await Task.yield()
        }
    }

    func finishRead(with verification: EntitlementVerification) {
        state.withLock { state in
            defer { state.readContinuation = nil }
            return state.readContinuation
        }?.resume(returning: verification)
    }
}
