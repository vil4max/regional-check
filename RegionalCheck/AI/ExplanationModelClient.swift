import Foundation

/// Provider-neutral model boundary. The agent runtime depends on this protocol,
/// never on a vendor transport. Concrete adapters: ScriptedExplanationModelClient
/// (deterministic tests) and future transports.
protocol ExplanationModelClient: Sendable {
    func respond(to request: ExplanationModelRequest) async throws -> ExplanationModelResponse
}

struct ExplanationModelRequest: Equatable, Sendable {
    var instructions: String
    var context: StatusExplanationContext
    var availableTools: [String]
    var turns: [ExplanationTurn]
}

enum ExplanationTurn: Equatable, Sendable {
    case prompt(String)
    case toolResult(name: String, payloadJSON: String)
}

enum ExplanationModelResponse: Equatable, Sendable {
    case finalText(String)
    case toolCalls([ExplanationToolCall])
}

/// Versioned runtime instruction. Prompt prose constrains behavior; Swift code
/// enforces the invariants (allowlisted tools, validation, limits).
enum ExplanationSystemInstructions {
    static let version = "2026-08-26"
    static let text = """
    You explain regional alert status produced by the Drive Check application.
    Rules you must follow:
    - Describe only the state supplied to you. Never infer or change alert state.
    - Never claim a region is safe or unsafe to drive. Never recommend routes,
      destinations, evacuation, shelter, or any emergency action.
    - Never invent facts that are absent from the supplied context or tool results.
    - If data may be outdated, call get_data_freshness and disclose staleness explicitly.
    - Use tools only when additional supplied application facts are required.
    - Answer concisely as plain explanatory prose.
    """
}

/// Deterministic scripted client for orchestration tests and DEBUG demo runs.
/// Each respond() consumes the next script entry; requests are recorded so tests
/// can assert exactly what the model saw in each turn.
actor ScriptedExplanationModelClient: ExplanationModelClient {
    enum ScriptedResponse: Sendable {
        case finalText(String)
        case toolCall(ExplanationToolCall)
        case transportFailure
    }

    struct ScriptExhaustedError: Error {}

    private var script: [ScriptedResponse]
    private(set) var requests: [ExplanationModelRequest] = []

    init(_ script: [ScriptedResponse]) {
        self.script = script
    }

    func respond(to request: ExplanationModelRequest) async throws -> ExplanationModelResponse {
        requests.append(request)
        guard !script.isEmpty else { throw ScriptExhaustedError() }
        switch script.removeFirst() {
        case let .finalText(text):
            return .finalText(text)
        case let .toolCall(call):
            return .toolCalls([call])
        case .transportFailure:
            throw ScriptExhaustedError()
        }
    }

    func recordedRequests() -> [ExplanationModelRequest] {
        requests
    }
}
