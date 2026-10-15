import Foundation

/// The callers of `StatusController.awaitStatusSettled()` waiting for the refresh in flight.
/// Each wait is bounded by `timeout`, so a caller never hangs when no refresh comes (e.g.
/// previews or fixtures that skip `MainTabViewModel.appear()`). A waiter registers synchronously
/// on the main actor before suspending, so a refresh settling in between cannot be missed; the
/// timeout and cancellation resume it by id, and each continuation resumes once.
@MainActor
final class StatusSettledWaiters {
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private let timeout: Duration

    init(timeout: Duration) {
        self.timeout = timeout
    }

    func wait() async {
        let id = UUID()
        let timeoutTask = Task { [weak self, timeout] in
            try? await Task.sleep(for: timeout)
            self?.resume(id)
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiters[id] = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resume(id)
            }
        }
        timeoutTask.cancel()
    }

    func resumeAll() {
        let pending = waiters.values
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    private func resume(_ id: UUID) {
        waiters.removeValue(forKey: id)?.resume()
    }
}
