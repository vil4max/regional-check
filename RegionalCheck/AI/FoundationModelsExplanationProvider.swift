import DriveCheckKit
import Foundation
import FoundationModels

/// Live transport over Apple's on-device system model (iOS 26+).
/// No API keys exist anywhere in this path: the model runs on device, no data
/// leaves it, and Private Cloud Compute variants are intentionally not used.
///
/// Orchestration note: LanguageModelSession schedules model↔tool turns internally.
/// Our deterministic boundaries still hold because both tools delegate to the same
/// StatusExplanationToolExecutor, share one call budget, emit trace events, and the
/// final text passes the same validator as the scripted runtime.
struct FoundationModelsExplanationProvider: StatusExplanationProviding {
    /// Availability is injectable so gating is deterministically testable.
    private let availability: @Sendable () -> SystemLanguageModel.Availability
    private let limits: ExplanationRunLimits
    private let environment: @Sendable () async -> RefreshEnvironment
    private let now: @Sendable () -> Date
    private let trace: (any ExplanationTraceRecording)?
    private let contextBuilder = StatusExplanationContextBuilder()

    init(
        limits: ExplanationRunLimits = ExplanationRunLimits(),
        environment: @escaping @Sendable () async -> RefreshEnvironment,
        now: @escaping @Sendable () -> Date = { Date() },
        trace: (any ExplanationTraceRecording)?,
        availability: @escaping @Sendable () -> SystemLanguageModel
            .Availability = { SystemLanguageModel.default.availability }
    ) {
        self.limits = limits
        self.environment = environment
        self.now = now
        self.trace = trace
        self.availability = availability
    }

    func explanation(for input: StatusExplanationInput) async throws -> String {
        guard let context = contextBuilder.makeContext(from: input) else {
            throw ExplanationRunError.unsupportedState
        }
        guard case .available = availability() else {
            throw ExplanationRunError.modelTransportFailed
        }

        let runID = UUID()
        await trace?.record(.runStarted(runID: runID, regionID: context.regionID))
        await trace?.record(.contextBuilt(runID: runID))

        let environmentValue = await environment()
        let executor = StatusExplanationToolExecutor(
            seed: .init(
                context: context,
                refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: environmentValue)
            ),
            now: now
        )
        // One budget per run keeps framework-scheduled tool turns inside product limits.
        let budget = ToolCallBudget(maxCalls: limits.maxToolCalls)
        let session = LanguageModelSession(
            model: .default,
            tools: [
                DeterministicStatusTool(
                    name: StatusExplanationToolName.currentStatus.rawValue,
                    description: "Returns the deterministic current status facts for the selected region.",
                    executor: executor,
                    budget: budget,
                    trace: trace,
                    runID: runID
                ),
                DeterministicStatusTool(
                    name: StatusExplanationToolName.dataFreshness.rawValue,
                    description: "Returns how old the alert data is and whether it is stale.",
                    executor: executor,
                    budget: budget,
                    trace: trace,
                    runID: runID
                )
            ],
            instructions: ExplanationSystemInstructions.text
        )

        do {
            // Guaranteed termination: a stalled or cancellation-ignoring
            // generation is abandoned at the deadline instead of holding the
            // explanation UI in loading forever.
            let response = try await BoundedAwait.value(timeout: limits.timeout) {
                try await session.respond(
                    to: StatusExplanationAgent.userPrompt(for: context),
                    generating: ExplanationDraft.self
                )
            }
            let validated = try ExplanationOutputValidator.validated(response.content.explanation, limits: limits)
            await trace?.record(.finalResponseValidated(runID: runID))
            // The framework owns internal model↔tool scheduling, so "model turns"
            // are not defined here; only deterministic tool calls are counted.
            await trace?.record(.frameworkRunCompleted(runID: runID, toolCallCount: budget.usedCount))
            return validated.text
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ExplanationRunError {
            await trace?.record(.runFailed(runID: runID, reason: error.traceReason))
            throw error
        } catch {
            try CancellationPolicy.rethrowIfCallerCancelled(error)
            // Framework-wrapped failures (including our budget/tool errors surfaced
            // through ToolCallError) degrade to the transport category for fallback.
            await trace?.record(.runFailed(runID: runID, reason: ExplanationRunError.modelTransportFailed.traceReason))
            throw ExplanationRunError.modelTransportFailed
        }
    }
}

/// Guided-generation schema for the final answer. The single explanatory field is
/// structural: there is no field the model could fill with recommendations.
@Generable
struct ExplanationDraft {
    @Guide(description: "Short factual explanation of the current regional alert status")
    var explanation: String
}

actor ToolCallBudget {
    private var remaining: Int
    private(set) var usedCount = 0

    init(maxCalls: Int) {
        remaining = maxCalls
    }

    func consume() throws {
        guard remaining > 0 else { throw ExplanationRunError.toolLimitExceeded }
        remaining -= 1
        usedCount += 1
    }
}

/// Adapter exposing one allowlisted deterministic tool to the system model.
/// The framework invokes it during generation; execution stays deterministic
/// Swift. Rejection by the shared run budget is traced before anything else,
/// matching the scripted runtime's observability semantics.
struct DeterministicStatusTool: Tool {
    typealias Arguments = EmptyToolArguments

    let name: String
    let description: String

    private let executor: StatusExplanationToolExecutor
    private let budget: ToolCallBudget
    private let trace: (any ExplanationTraceRecording)?
    private let runID: UUID

    init(
        name: String,
        description: String,
        executor: StatusExplanationToolExecutor,
        budget: ToolCallBudget,
        trace: (any ExplanationTraceRecording)?,
        runID: UUID
    ) {
        self.name = name
        self.description = description
        self.executor = executor
        self.budget = budget
        self.trace = trace
        self.runID = runID
    }

    func call(arguments _: Arguments) async throws -> String {
        await trace?.record(.toolRequested(runID: runID, name: name))
        do {
            try await budget.consume()
        } catch {
            await trace?.record(.toolFailed(
                runID: runID,
                name: name,
                reason: StatusExplanationAgent.toolBudgetTraceReason
            ))
            throw error
        }
        do {
            let payload = try executor.execute(ExplanationToolCall(name: name, argumentsJSON: "{}"))
            await trace?.record(.toolSucceeded(runID: runID, name: name))
            return payload
        } catch {
            let reason = (error as? ToolExecutionError)?.traceReason ?? "execution"
            await trace?.record(.toolFailed(runID: runID, name: name, reason: reason))
            throw error
        }
    }
}

/// Argument-free tool arguments. Guided generation requires at least one
/// property; the model fills it, deterministic execution ignores it.
@Generable
struct EmptyToolArguments {
    @Guide(description: "Unused placeholder; tools take no arguments")
    var unused: Bool
}
