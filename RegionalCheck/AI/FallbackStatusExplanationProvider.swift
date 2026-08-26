import Foundation

/// AI-backed explanation strategy: bounded agent runtime over an injectable
/// model client. Deterministic fallback lives one layer above (composite).
struct AgentStatusExplanationProvider: StatusExplanationProviding {
    private let agent: StatusExplanationAgent
    private let contextBuilder = StatusExplanationContextBuilder()
    /// Captures the refresh environment once at run start, so freshness facts are
    /// computed against the policy state observed when the user asked.
    private let environment: @Sendable () async -> RefreshEnvironment
    private let now: @Sendable () -> Date

    init(
        agent: StatusExplanationAgent,
        environment: @escaping @Sendable () async -> RefreshEnvironment,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.agent = agent
        self.environment = environment
        self.now = now
    }

    func explanation(for input: StatusExplanationInput) async throws -> String {
        guard let context = contextBuilder.makeContext(from: input) else {
            throw ExplanationRunError.unsupportedState
        }
        let environmentValue = await environment()
        let executor = StatusExplanationToolExecutor(
            seed: .init(
                context: context,
                refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: environmentValue)
            ),
            now: now
        )
        return try await agent.run(context: context, executor: executor).text
    }
}

/// Composition-level fallback selection. AI failure degrades to the localized
/// deterministic explanation; cancellation never produces a stale fallback.
/// SwiftUI never picks providers.
struct FallbackStatusExplanationProvider: StatusExplanationProviding {
    let primary: any StatusExplanationProviding
    let fallback: any StatusExplanationProviding
    var trace: (any ExplanationTraceRecording)?

    func explanation(for input: StatusExplanationInput) async throws -> String {
        do {
            return try await primary.explanation(for: input)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Caller cancellation outranks every failure shape, including
            // transport errors that mask cancellation as domain failures.
            try CancellationPolicy.rethrowIfCallerCancelled(error)
            // A cancel landing between primary failure and fallback start
            // must also win instead of producing fallback material.
            try Task.checkCancellation()
            let reason = (error as? ExplanationRunError)?.traceReason ?? "model_transport"
            await trace?.record(.fallbackUsed(reason: reason))
            return try await fallback.explanation(for: input)
        }
    }
}
