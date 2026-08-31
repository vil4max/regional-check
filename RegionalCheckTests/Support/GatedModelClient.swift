import Foundation
@testable import RegionalCheck

/// Model double that suspends until the test resumes it, with cooperative
/// cancellation like a real transport.
actor GatedModelClient: ExplanationModelClient {
    private var continuation: CheckedContinuation<ExplanationModelResponse, any Error>?
    private var cancellationObserved = false
    private(set) var requestCount = 0

    func respond(to _: ExplanationModelRequest) async throws -> ExplanationModelResponse {
        requestCount += 1
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { pending in
                // Cancellation may arrive before the suspension is installed.
                if cancellationObserved {
                    pending.resume(throwing: CancellationError())
                    return
                }
                continuation = pending
            }
        }, onCancel: {
            Task { await self.resumeWithCancellation() }
        })
    }

    func resume(_ result: Result<ExplanationModelResponse, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    func waitUntilSuspended() async {
        while continuation == nil, !cancellationObserved {
            await Task.yield()
        }
    }

    private func resumeWithCancellation() {
        cancellationObserved = true
        resume(.failure(CancellationError()))
    }
}
