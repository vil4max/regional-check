import Foundation

struct FallbackStatusDetailsProvider: StatusDetailsSummarizing {
    let primary: any StatusDetailsSummarizing
    let fallback: any StatusDetailsSummarizing
    var trace: (any ExplanationTraceRecording)?

    func summary(for input: StatusDetailsInput) async throws -> String {
        do {
            return try await primary.summary(for: input)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try CancellationPolicy.rethrowIfCallerCancelled(error)
            try Task.checkCancellation()
            let reason = (error as? ExplanationRunError)?.traceReason ?? "model_transport"
            await trace?.record(.fallbackUsed(reason: reason))
            return try await fallback.summary(for: input)
        }
    }
}
