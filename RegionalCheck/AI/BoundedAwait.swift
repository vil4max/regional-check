import Foundation

/// Caller cancellation outranks every underlying failure: no layer may convert
/// it into fallback material, even when a transport masks cancellation as a
/// domain error (for example URLError.cancelled).
enum CancellationPolicy {
    static func rethrowIfCallerCancelled(_ error: any Error) throws {
        if error is CancellationError {
            throw CancellationError()
        }
        if Task.isCancelled {
            throw CancellationError()
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            throw CancellationError()
        }
    }
}

/// Guaranteed-termination await: returns the operation result, or fails with
/// `deadlineExceeded` no later than the given timeout — even when the operation
/// never returns and ignores cooperative cancellation.
///
/// Engineering lesson encoded here: cancellation, timeout, and guaranteed
/// termination are three different properties. StructuredConcurrency joins
/// cannot guarantee termination because a hung child blocks the group, so the
/// losing side is abandoned (unstructured), never awaited.
enum BoundedAwait {
    protocol Sleeping: Sendable {
        func sleep(for duration: Duration) async throws
    }

    struct ContinuousSleeping: Sleeping {
        func sleep(for duration: Duration) async throws {
            try await ContinuousClock().sleep(for: duration)
        }
    }

    static func value<T: Sendable>(
        timeout: Duration,
        sleeping: any Sleeping = ContinuousSleeping(),
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let box = CompletionBox<T>()
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                box.install(
                    continuation,
                    timeout: timeout,
                    sleeping: sleeping,
                    operation: operation
                )
            }
        }, onCancel: {
            box.externalCancel()
        })
    }
}

/// Single-resume guard around a continuation plus handles for the racing
/// work/watcher tasks. Lock-based on purpose: resume decisions must be atomic
/// across the three competing sources (work, timeout, caller cancellation).
private final class CompletionBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var work: Task<Void, Never>?
    private var watcher: Task<Void, Never>?
    /// Work/watcher race winner has resumed the continuation.
    private var settled = false
    /// Caller cancellation may arrive before installation; it must win too.
    private var externallyCancelled = false

    func install(
        _ continuation: CheckedContinuation<T, any Error>,
        timeout: Duration,
        sleeping: any BoundedAwait.Sleeping,
        operation: @escaping @Sendable () async throws -> T
    ) {
        lock.lock()
        if settled || externallyCancelled {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        lock.unlock()

        let workTask = Task { [weak self] in
            do {
                let value = try await operation()
                _ = self?.settle(.success(value))
            } catch {
                _ = self?.settle(.failure(error))
            }
        }
        let watcherTask = Task { [weak self] in
            try? await sleeping.sleep(for: timeout)
            _ = self?.settle(.failure(ExplanationRunError.deadlineExceeded))
            workTask.cancel()
        }

        lock.lock()
        if settled || externallyCancelled {
            lock.unlock()
            workTask.cancel()
            watcherTask.cancel()
            return
        }
        work = workTask
        watcher = watcherTask
        lock.unlock()
    }

    func externalCancel() {
        lock.lock()
        externallyCancelled = true
        let pending = continuation
        let runningWork = work
        let runningWatcher = watcher
        continuation = nil
        work = nil
        watcher = nil
        lock.unlock()
        guard let pending else { return }
        pending.resume(throwing: CancellationError())
        runningWork?.cancel()
        runningWatcher?.cancel()
    }

    /// Resumes at most once and cancels the sibling tasks. Returns false when
    /// another source already settled the box.
    private func settle(_ result: Result<T, any Error>) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !settled, let pending = continuation else { return false }
        settled = true
        let runningWork = work
        let runningWatcher = watcher
        continuation = nil
        work = nil
        watcher = nil
        pending.resume(with: result)
        runningWork?.cancel()
        runningWatcher?.cancel()
        return true
    }
}
