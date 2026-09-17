import Foundation
import FoundationModels

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

enum ModelStatusSource {
    static let publicAlertFeed = "public_alert_feed"
}

/// Normalizes framework-surfaced errors back to runtime categories.
/// Device-validated (2026-08-26): the framework wraps typed tool errors in
/// ToolCallError and preserves the original as underlyingError.
enum ExplanationTransportNormalizer {
    static func normalized(_ error: any Error) -> ExplanationRunError? {
        if let runError = error as? ExplanationRunError {
            return runError
        }
        if let toolCallError = error as? LanguageModelSession.ToolCallError {
            return toolCallError.underlyingError as? ExplanationRunError
        }
        return nil
    }
}
