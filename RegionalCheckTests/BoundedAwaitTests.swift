import Foundation
@testable import RegionalCheck
import Testing

/// Proves the guaranteed-termination property of BoundedAwait:
/// cancellation, timeout, and termination are three distinct guarantees.
struct BoundedAwaitTests {
    /// Never returns and deliberately ignores cooperative cancellation —
    /// the worst-case transport shape.
    private static func hangIgnoringCancellation() async {
        while true {
            try? await Task.sleep(for: .seconds(60))
        }
    }

    private struct ImmediateSleeping: BoundedAwait.Sleeping {
        func sleep(for _: Duration) async throws {}
    }

    /// Long enough that the deadline can never win a fast test deterministically,
    /// yet cancellable so the watcher task does not leak.
    private struct LongCancellableSleeping: BoundedAwait.Sleeping {
        func sleep(for _: Duration) async throws {
            try await ContinuousClock().sleep(for: .seconds(3600))
        }
    }

    @Test
    func hungOperationFailsByDeadlineDespiteIgnoredCancellation() async {
        do {
            _ = try await BoundedAwait.value(
                timeout: .seconds(30),
                sleeping: ImmediateSleeping(),
                operation: { await Self.hangIgnoringCancellation() }
            )
            Issue.record("Expected deadlineExceeded")
        } catch {
            #expect(error as? ExplanationRunError == .deadlineExceeded)
        }
    }

    @Test
    func completingOperationReturnsBeforeDeadline() async throws {
        let value = try await BoundedAwait.value(
            timeout: .seconds(30),
            sleeping: LongCancellableSleeping(),
            operation: { 42 }
        )
        #expect(value == 42)
    }

    @Test
    func failingOperationPropagatesItsError() async {
        struct Boom: Error {}
        do {
            _ = try await BoundedAwait.value(
                timeout: .seconds(30),
                sleeping: LongCancellableSleeping(),
                operation: { throw Boom() }
            )
            Issue.record("Expected Boom")
        } catch {
            #expect(error is Boom)
        }
    }

    @Test
    func callerCancellationBeatsHungOperation() async throws {
        let task = Task {
            try await BoundedAwait.value(
                timeout: .seconds(30),
                sleeping: LongCancellableSleeping(),
                operation: { await Self.hangIgnoringCancellation() }
            )
        }
        // Give the continuation a chance to install before cancelling.
        await Task.yield()
        await Task.yield()
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected CancellationError")
        } catch {
            #expect(error is CancellationError)
        }
    }
}
