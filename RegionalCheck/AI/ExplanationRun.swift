import Foundation

struct ExplanationRunLimits: Sendable {
    var maxFinalCharacters = 1200
    /// Per-run wall-clock budget. Checked between steps; each model call is also
    /// bounded by its transport.
    var timeout: Duration = .seconds(30)
}

/// Runtime error taxonomy. Internal engineering errors are never shown directly
/// to end users; the composite provider maps them to deterministic fallback.
enum ExplanationRunError: Error, Equatable {
    case invalidFinalOutput
    case modelTransportFailed
    case deadlineExceeded

    var traceReason: String {
        switch self {
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
