import Foundation

struct ExplanationRunLimits: Sendable {
    var maxModelTurns = 4
    var maxToolCalls = 3
    var maxFinalCharacters = 1200
    /// Per-run wall-clock budget. Checked between steps; each model call is also
    /// bounded by its transport.
    var timeout: Duration = .seconds(30)
}

/// Runtime error taxonomy. Internal engineering errors are never shown directly
/// to end users; the composite provider maps them to deterministic fallback.
enum ExplanationRunError: Error, Equatable {
    case unsupportedState
    case stepLimitExceeded
    case toolLimitExceeded
    case unknownTool(String)
    case invalidToolArguments(String)
    case invalidFinalOutput
    case modelTransportFailed
    case deadlineExceeded

    var traceReason: String {
        switch self {
        case .unsupportedState:
            "unsupported_state"
        case .stepLimitExceeded:
            "step_limit"
        case .toolLimitExceeded:
            "tool_limit"
        case .unknownTool:
            "unknown_tool"
        case .invalidToolArguments:
            "invalid_tool_arguments"
        case .invalidFinalOutput:
            "invalid_final_output"
        case .modelTransportFailed:
            "model_transport"
        case .deadlineExceeded:
            "deadline"
        }
    }
}

/// Validated structured result. Model text crosses an untrusted probabilistic
/// boundary and enters presentation state only after this validation.
struct GeneratedStatusExplanation: Equatable, Sendable {
    let text: String
}

/// Injectable run timing so deadline behavior is deterministically testable.
protocol ExplanationRunTiming: Sendable {
    func now() -> ContinuousClock.Instant
}

struct ContinuousRunTiming: ExplanationRunTiming {
    private let clock = ContinuousClock()

    func now() -> ContinuousClock.Instant {
        clock.now
    }
}

/// Swift owns the agent loop: limits, cancellation, validation, termination.
/// The LLM never owns execution.
struct StatusExplanationAgent: Sendable {
    /// Shared diagnostic token when a tool invocation is rejected because the
    /// per-run budget is exhausted; identical across all transports.
    static let toolBudgetTraceReason = "tool_limit"

    let client: any ExplanationModelClient
    let limits: ExplanationRunLimits
    let timing: any ExplanationRunTiming
    let trace: (any ExplanationTraceRecording)?

    func run(
        context: StatusExplanationContext,
        executor: StatusExplanationToolExecutor,
        runID: UUID = UUID()
    ) async throws -> GeneratedStatusExplanation {
        await trace?.record(.runStarted(runID: runID, regionID: context.regionID))
        await trace?.record(.contextBuilt(runID: runID))

        var turns: [ExplanationTurn] = [.prompt(Self.userPrompt(for: context))]
        var modelTurns = 0
        var toolCalls = 0
        let deadline = timing.now().advanced(by: limits.timeout)

        while true {
            try Task.checkCancellation()
            guard modelTurns < limits.maxModelTurns else {
                await trace?.record(.runFailed(runID: runID, reason: ExplanationRunError.stepLimitExceeded.traceReason))
                throw ExplanationRunError.stepLimitExceeded
            }
            guard timing.now() < deadline else {
                await trace?.record(.runFailed(runID: runID, reason: ExplanationRunError.deadlineExceeded.traceReason))
                throw ExplanationRunError.deadlineExceeded
            }

            modelTurns += 1
            let request = ExplanationModelRequest(
                instructions: ExplanationSystemInstructions.text,
                context: context,
                availableTools: StatusExplanationToolName.allCases.map(\.rawValue),
                turns: turns
            )
            await trace?.record(.modelRequested(runID: runID, step: modelTurns))
            let response: ExplanationModelResponse
            do {
                response = try await client.respond(to: request)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try CancellationPolicy.rethrowIfCallerCancelled(error)
                await trace?.record(.runFailed(
                    runID: runID,
                    reason: ExplanationRunError.modelTransportFailed.traceReason
                ))
                throw ExplanationRunError.modelTransportFailed
            }

            switch response {
            case let .finalText(raw):
                let validated = try ExplanationOutputValidator.validated(raw, limits: limits)
                await trace?.record(.finalResponseValidated(runID: runID))
                await trace?.record(.runCompleted(runID: runID, modelTurns: modelTurns, toolCalls: toolCalls))
                return validated
            case let .toolCalls(calls):
                for call in calls {
                    if toolCalls >= limits.maxToolCalls {
                        // Budget rejection is observable before the executor runs,
                        // with identical semantics on every transport.
                        await trace?.record(.toolRequested(runID: runID, name: call.name))
                        await trace?.record(.toolFailed(
                            runID: runID,
                            name: call.name,
                            reason: Self.toolBudgetTraceReason
                        ))
                        await trace?.record(.runFailed(
                            runID: runID,
                            reason: ExplanationRunError.toolLimitExceeded.traceReason
                        ))
                        throw ExplanationRunError.toolLimitExceeded
                    }
                    toolCalls += 1
                    await trace?.record(.toolRequested(runID: runID, name: call.name))
                    let payload: String
                    do {
                        payload = try executor.execute(call)
                    } catch let toolError as ToolExecutionError {
                        // Chosen policy: an unsupported or malformed tool request fails
                        // the run deterministically instead of negotiating with the model.
                        await trace?.record(.toolFailed(runID: runID, name: call.name, reason: toolError.traceReason))
                        let runError: ExplanationRunError = switch toolError {
                        case .unknownTool:
                            .unknownTool(call.name)
                        case .invalidArguments:
                            .invalidToolArguments(call.argumentsJSON)
                        }
                        await trace?.record(.runFailed(runID: runID, reason: runError.traceReason))
                        throw runError
                    }
                    await trace?.record(.toolSucceeded(runID: runID, name: call.name))
                    turns.append(.toolResult(name: call.name, payloadJSON: payload))
                }
            }
        }
    }

    /// Compact factual prompt serialization of the context projection.
    /// Freshness is intentionally excluded here: it is a computed fact behind
    /// get_data_freshness, so the model never does timestamp math itself.
    static func userPrompt(for context: StatusExplanationContext) -> String {
        let phaseLabel = context.phase == .quiet ? "All clear" : "Alert active"
        let checkedAt = context.checkedAt.formatted(
            .iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false)
        )
        return """
        Current resolved status:
        region_id: \(context.regionID)
        region: \(context.regionTitle)
        phase: \(phaseLabel)
        source: \(ModelStatusSource.publicAlertFeed)
        checked_at: \(checkedAt)
        Explain this status for the user.
        """
    }
}

extension ToolExecutionError {
    var traceReason: String {
        switch self {
        case let .unknownTool(name):
            "unknown:\(name)"
        case .invalidArguments:
            "invalid_arguments"
        }
    }
}

/// Shared final-output validation for every transport. Model output is untrusted
/// probabilistic content and must pass here before entering presentation state.
enum ExplanationOutputValidator {
    static func validated(
        _ raw: String,
        limits: ExplanationRunLimits
    ) throws -> GeneratedStatusExplanation {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ExplanationRunError.invalidFinalOutput }
        guard trimmed.count <= limits.maxFinalCharacters else { throw ExplanationRunError.invalidFinalOutput }
        return GeneratedStatusExplanation(text: trimmed)
    }
}
