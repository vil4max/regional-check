import DriveCheckKit
import Foundation
import FoundationModels
@testable import RegionalCheck
import Testing

/// Empirical Foundation Models validation on Apple Intelligence hardware.
/// Opt-in only: run with TEST_RUNNER_RC_FM_DEVICE=1 against a physical device.
/// Every test records observed behavior; model-quality assertions are soft,
/// runtime-behavior observations are the actual deliverable.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["RC_FM_DEVICE"] == "1"))
struct FoundationModelsDeviceValidationTests {
    private let store = ExplanationTraceStore()

    private func note(_ text: String) {
        print("[FM-VALIDATE] \(text)")
    }

    private func requireAvailable() throws {
        switch SystemLanguageModel.default.availability {
        case .available:
            note("availability: available")
        case let .unavailable(reason):
            note("availability: unavailable reason=\(String(describing: reason))")
            Issue.record("Apple Intelligence unavailable on this device: \(reason)")
        default:
            note("availability: unknown case=\(SystemLanguageModel.default.availability)")
            Issue.record("Unknown availability case")
        }
    }

    private func makeContext(phase: StatusExplanationContext.Phase = .quiet) -> StatusExplanationContext {
        StatusExplanationContext(
            regionID: "kyivCity",
            regionTitle: "Kyiv City",
            phase: phase,
            source: "device-validation-feed",
            checkedAt: Date().addingTimeInterval(-90)
        )
    }

    private func makeExecutor(context: StatusExplanationContext) -> StatusExplanationToolExecutor {
        StatusExplanationToolExecutor(
            seed: .init(context: context, refreshIntervalSeconds: RefreshPolicy.baselineSeconds),
            now: { Date() }
        )
    }

    private func makeSession(
        context: StatusExplanationContext,
        budget: ToolCallBudget
    ) -> LanguageModelSession {
        let executor = makeExecutor(context: context)
        return LanguageModelSession(
            model: .default,
            tools: [
                DeterministicStatusTool(
                    name: StatusExplanationToolName.currentStatus.rawValue,
                    description: "Returns the deterministic current status facts for the selected region.",
                    executor: executor,
                    budget: budget,
                    trace: store,
                    runID: UUID()
                ),
                DeterministicStatusTool(
                    name: StatusExplanationToolName.dataFreshness.rawValue,
                    description: "Returns how old the alert data is and whether it is stale.",
                    executor: executor,
                    budget: budget,
                    trace: store,
                    runID: UUID()
                )
            ],
            instructions: ExplanationSystemInstructions.text
        )
    }

    private func dumpTrace(prefix: String) async {
        for stored in await store.storedEvents() {
            note("\(prefix) trace#\(stored.sequence): \(stored.event)")
        }
        await store.reset()
    }

    // MARK: 1 — availability

    @Test
    func availabilityAndSmokeResponse() async throws {
        try requireAvailable()
        let session = LanguageModelSession(model: .default, instructions: AnswerBriefly.instructions)
        let response = try await session.respond(to: "Reply with exactly: OK")
        note("smoke response: '\(response.content)'")
        #expect(!response.content.isEmpty)
    }

    // MARK: 2–3 — real tool workflows

    @Test(arguments: [
        (StatusExplanationContext.Phase.quiet, "get_current_status"),
        (StatusExplanationContext.Phase.alarm, "get_data_freshness")
    ])
    func realToolWorkflow(phase: StatusExplanationContext.Phase, encouragedTool: String) async throws {
        try requireAvailable()
        let context = makeContext(phase: phase)
        let budget = ToolCallBudget(maxCalls: 3)
        let session = makeSession(context: context, budget: budget)
        let prompt = """
        \(StatusExplanationAgent.userPrompt(for: context))
        Before answering, call \(encouragedTool).
        """
        let response = try await session.respond(
            to: prompt,
            generating: ExplanationDraft.self
        )
        note("workflow(\(phase.rawValue)) final: '\(response.content.explanation)'")
        await note("workflow(\(phase.rawValue)) toolCalls used: \(budget.usedCount)")
        #expect(!response.content.explanation.isEmpty)
        await dumpTrace(prefix: "workflow(\(phase.rawValue))")
    }

    // MARK: 4 — multi-tool invocation

    @Test
    func multiToolInvocationBehavior() async throws {
        try requireAvailable()
        let context = makeContext()
        let budget = ToolCallBudget(maxCalls: 3)
        let session = makeSession(context: context, budget: budget)
        let prompt = """
        \(StatusExplanationAgent.userPrompt(for: context))
        Before answering you MUST call both get_current_status and get_data_freshness.
        """
        let response = try await session.respond(to: prompt, generating: ExplanationDraft.self)
        let used = await budget.usedCount
        note("multi-tool final: '\(response.content.explanation)'")
        note("multi-tool toolCalls used: \(used)")
        #expect(used >= 1)
        if used < 2 {
            note("OBSERVATION: model did not call both tools (called \(used))")
        }
        await dumpTrace(prefix: "multi-tool")
    }

    // MARK: 5 — tool-limit error shape / wrapping (R2-2 evidence)

    @Test
    func toolLimitErrorShapeObservation() async throws {
        try requireAvailable()
        let context = makeContext()
        let budget = ToolCallBudget(maxCalls: 1)
        let session = makeSession(context: context, budget: budget)
        let prompt = """
        \(StatusExplanationAgent.userPrompt(for: context))
        You MUST call get_current_status AND THEN get_data_freshness AND THEN get_current_status again before answering.
        """
        do {
            _ = try await session.respond(to: prompt, generating: ExplanationDraft.self)
            note("tool-limit: NO ERROR surfaced (budget not exhausted or framework tolerated it)")
        } catch {
            note("tool-limit error concrete type: \(type(of: error))")
            note("tool-limit error description: \(String(describing: error))")
            note("tool-limit is ExplanationRunError directly: \(error is ExplanationRunError)")
            note("tool-limit is CancellationError: \(error is CancellationError)")
        }
        await dumpTrace(prefix: "tool-limit")
    }

    // MARK: 6 — caller cancellation during respond

    @Test
    func callerCancellationDuringRespond() async throws {
        try requireAvailable()
        let session = LanguageModelSession(model: .default, instructions: AnswerBriefly.instructions)
        let task = Task {
            try await session.respond(to: LongPrompt.text)
        }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        do {
            // The join itself is bounded: an unbounded wait here could freeze
            // the whole device run instead of recording the observation.
            let text = try await BoundedAwait.value(timeout: .seconds(180)) {
                try await task.value.content
            }
            note("cancellation: respond completed anyway with \(text.count) chars")
            Issue.record("respond completed despite caller cancellation")
        } catch let error as ExplanationRunError where error == .deadlineExceeded {
            note("cancellation OBSERVATION: respond did not terminate within 180s after cancel")
        } catch {
            note("cancellation error type: \(type(of: error))")
            note("cancellation error description: \(String(describing: error))")
        }
    }

    // MARK: 7 — deadline while respond is active

    @Test
    func deadlineWhileRespondActive() async throws {
        try requireAvailable()
        let session = LanguageModelSession(model: .default, instructions: AnswerBriefly.instructions)
        let started = ContinuousClock().now
        do {
            let text = try await BoundedAwait.value(timeout: .seconds(5)) {
                try await session.respond(to: LongPrompt.text).content
            }
            note("deadline: generation finished under 5s (\(text.count) chars)")
        } catch {
            let elapsed = ContinuousClock().now - started
            note("deadline error type: \(type(of: error))")
            note("deadline elapsed: \(elapsed)")
            #expect(error as? ExplanationRunError == .deadlineExceeded)
            #expect(elapsed < .seconds(8))
        }
    }

    // MARK: 8 — trace semantics summary

    @Test
    func traceSemanticsSummary() {
        note("trace events recorded across this suite are listed inline above per scenario")
        #expect(true)
    }
}

private enum AnswerBriefly {
    static let instructions = "Answer briefly and factually."
}

private enum LongPrompt {
    static let text = """
    Write a very detailed essay about regional alert systems, at least 800 words.
    Do not stop early.
    """
}
