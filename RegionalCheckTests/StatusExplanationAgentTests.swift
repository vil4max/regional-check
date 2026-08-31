// swiftlint:disable force_unwrapping
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct StatusExplanationAgentTests {
    private let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let knownRunID = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000000")!

    private func makeContext(
        phase: StatusExplanationContext.Phase = .quiet
    ) -> StatusExplanationContext {
        StatusExplanationContext(
            regionID: "kyivCity",
            regionTitle: "Kyiv",
            phase: phase,
            source: "test-feed",
            checkedAt: checkedAt
        )
    }

    private func makeExecutor(
        context: StatusExplanationContext,
        now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_700_000_030) }
    ) -> StatusExplanationToolExecutor {
        StatusExplanationToolExecutor(
            seed: .init(context: context, refreshIntervalSeconds: 60),
            now: now
        )
    }

    private func makeAgent(
        client: any ExplanationModelClient,
        limits: ExplanationRunLimits = ExplanationRunLimits(),
        trace: (any ExplanationTraceRecording)? = nil
    ) -> StatusExplanationAgent {
        StatusExplanationAgent(client: client, limits: limits, timing: ContinuousRunTiming(), trace: trace)
    }

    @Test
    func finalResponseWithZeroToolsCompletes() async throws {
        let client = ScriptedExplanationModelClient([.finalText("Kyiv is all clear.")])
        let agent = makeAgent(client: client)
        let result = try await agent.run(context: makeContext(), executor: makeExecutor(context: makeContext()))
        #expect(result.text == "Kyiv is all clear.")
        let requests = await client.recordedRequests()
        #expect(requests.count == 1)
        #expect(requests[0].turns.count == 1)
    }

    @Test
    func singleToolWorkflowCompletesAndFeedsResultBackToModel() async throws {
        let context = makeContext()
        let client = ScriptedExplanationModelClient([
            .toolCall(ExplanationToolCall(name: "get_current_status", argumentsJSON: "{}")),
            .finalText("Status explained.")
        ])
        let agent = makeAgent(client: client)

        let result = try await agent.run(context: context, executor: makeExecutor(context: context))

        #expect(result.text == "Status explained.")
        let requests = await client.recordedRequests()
        #expect(requests.count == 2)
        // The tool payload produced by deterministic Swift must appear as the
        // model's input on the next turn.
        guard case let .toolResult(name, payload) = requests[1].turns.last else {
            Issue.record("Expected trailing tool result turn")
            return
        }
        #expect(name == "get_current_status")
        #expect(payload.contains("all_clear"))
    }

    @Test
    func multiStepWorkflowExecutesTwoToolsBeforeFinal() async throws {
        let context = makeContext()
        let client = ScriptedExplanationModelClient([
            .toolCall(ExplanationToolCall(name: "get_current_status", argumentsJSON: "{}")),
            .toolCall(ExplanationToolCall(name: "get_data_freshness", argumentsJSON: "{}")),
            .finalText("Fresh and quiet.")
        ])
        let agent = makeAgent(client: client)

        let result = try await agent.run(context: context, executor: makeExecutor(context: context))

        #expect(result.text == "Fresh and quiet.")
        let requests = await client.recordedRequests()
        #expect(requests.count == 3)
        let toolResults = requests.compactMap { request -> String? in
            if case let .toolResult(name, _) = request.turns.last {
                name
            } else {
                nil
            }
        }
        #expect(toolResults == ["get_current_status", "get_data_freshness"])
    }

    @Test
    func unknownToolFailsRunDeterministically() async {
        let context = makeContext()
        let store = ExplanationTraceStore()
        let client = ScriptedExplanationModelClient([
            .toolCall(ExplanationToolCall(name: "launch_missiles", argumentsJSON: "{}"))
        ])
        let agent = makeAgent(client: client, trace: store)

        await #expect(throws: ExplanationRunError.unknownTool("launch_missiles")) {
            try await agent.run(context: context, executor: makeExecutor(context: context))
        }
        let events = await store.recordedEvents()
        #expect(events.contains(.toolFailed(
            runID: events.firstID() ?? UUID(),
            name: "launch_missiles",
            reason: "unknown:launch_missiles"
        )))
    }

    @Test
    func malformedArgumentsFailRunDeterministically() async {
        let context = makeContext()
        let client = ScriptedExplanationModelClient([
            .toolCall(ExplanationToolCall(name: "get_current_status", argumentsJSON: "{\"region\":\"lviv\"}"))
        ])
        let agent = makeAgent(client: client)

        await #expect(throws: ExplanationRunError.invalidToolArguments("{\"region\":\"lviv\"}")) {
            try await agent.run(context: context, executor: makeExecutor(context: context))
        }
    }

    @Test
    func stepLimitTerminatesRunLoop() async {
        let context = makeContext()
        // Every turn demands another tool; the model-turn budget must end it.
        var script: [ScriptedExplanationModelClient.ScriptedResponse] = []
        for _ in 0 ..< 8 {
            script.append(.toolCall(ExplanationToolCall(name: "get_data_freshness", argumentsJSON: "{}")))
        }
        let client = ScriptedExplanationModelClient(script)
        var limits = ExplanationRunLimits()
        limits.maxModelTurns = 4
        limits.maxToolCalls = 99
        let agent = makeAgent(client: client, limits: limits)

        await #expect(throws: ExplanationRunError.stepLimitExceeded) {
            try await agent.run(context: context, executor: makeExecutor(context: context))
        }
    }

    @Test
    func toolLimitTerminatesRun() async {
        let context = makeContext()
        var script: [ScriptedExplanationModelClient.ScriptedResponse] = []
        for _ in 0 ..< 8 {
            script.append(.toolCall(ExplanationToolCall(name: "get_data_freshness", argumentsJSON: "{}")))
        }
        let client = ScriptedExplanationModelClient(script)
        var limits = ExplanationRunLimits()
        limits.maxModelTurns = 99
        limits.maxToolCalls = 3
        let agent = makeAgent(client: client, limits: limits)

        await #expect(throws: ExplanationRunError.toolLimitExceeded) {
            try await agent.run(context: context, executor: makeExecutor(context: context))
        }
    }

    @Test(arguments: ["", "   \n  "])
    func emptyFinalOutputIsRejected(text: String) async {
        let client = ScriptedExplanationModelClient([.finalText(text)])
        let agent = makeAgent(client: client)
        await #expect(throws: ExplanationRunError.invalidFinalOutput) {
            try await agent.run(context: makeContext(), executor: makeExecutor(context: makeContext()))
        }
    }

    @Test
    func oversizedFinalOutputIsRejected() async {
        let oversized = String(repeating: "a", count: 1201)
        let client = ScriptedExplanationModelClient([.finalText(oversized)])
        let agent = makeAgent(client: client)
        await #expect(throws: ExplanationRunError.invalidFinalOutput) {
            try await agent.run(context: makeContext(), executor: makeExecutor(context: makeContext()))
        }
    }

    @Test
    func transportFailureMapsToRuntimeCategory() async {
        let client = ScriptedExplanationModelClient([.transportFailure])
        let agent = makeAgent(client: client)
        await #expect(throws: ExplanationRunError.modelTransportFailed) {
            try await agent.run(context: makeContext(), executor: makeExecutor(context: makeContext()))
        }
    }

    @Test
    func deadlineExceedsDeterministicallyWithZeroBudget() async {
        let client = ScriptedExplanationModelClient([.finalText("late")])
        var limits = ExplanationRunLimits()
        limits.timeout = .zero
        let agent = makeAgent(client: client, limits: limits)
        await #expect(throws: ExplanationRunError.deadlineExceeded) {
            try await agent.run(context: makeContext(), executor: makeExecutor(context: makeContext()))
        }
    }

    @Test
    func cancellationPropagatesThroughRuntimeWithoutResult() async throws {
        let gated = GatedModelClient()
        let agent = makeAgent(client: gated)
        let context = makeContext()

        let task = Task {
            try await agent.run(context: context, executor: makeExecutor(context: context))
        }
        await gated.waitUntilSuspended()
        task.cancel()
        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }

    @Test
    func deterministicInputStateIsUntouchedByRuns() async throws {
        let context = makeContext(phase: .alarm)
        let snapshotBefore = context
        let successClient = ScriptedExplanationModelClient([.finalText("ok")])
        let agent = makeAgent(client: successClient)
        _ = try await agent.run(context: context, executor: makeExecutor(context: context))
        #expect(context == snapshotBefore)

        let failureClient = ScriptedExplanationModelClient([.transportFailure])
        let failingAgent = makeAgent(client: failureClient)
        await #expect(throws: ExplanationRunError.modelTransportFailed) {
            try await failingAgent.run(context: context, executor: makeExecutor(context: context))
        }
        #expect(context == snapshotBefore)
    }

    @Test
    func traceRecordsFullLifecycleForScriptedRun() async throws {
        let context = makeContext()
        let store = ExplanationTraceStore()
        let client = ScriptedExplanationModelClient([
            .toolCall(ExplanationToolCall(name: "get_current_status", argumentsJSON: "{}")),
            .finalText("Done")
        ])
        let agent = makeAgent(client: client, trace: store)

        _ = try await agent.run(context: context, executor: makeExecutor(context: context), runID: knownRunID)

        let events = await store.recordedEvents()
        #expect(events.contains(.runStarted(runID: knownRunID, regionID: "kyivCity")))
        #expect(events.contains(.contextBuilt(runID: knownRunID)))
        #expect(events.contains(.modelRequested(runID: knownRunID, step: 1)))
        #expect(events.contains(.modelRequested(runID: knownRunID, step: 2)))
        #expect(events.contains(.toolRequested(runID: knownRunID, name: "get_current_status")))
        #expect(events.contains(.toolSucceeded(runID: knownRunID, name: "get_current_status")))
        #expect(events.contains(.finalResponseValidated(runID: knownRunID)))
        #expect(events.contains(.runCompleted(runID: knownRunID, modelTurns: 2, toolCalls: 1)))
    }

    @Test
    func traceContainsNoPayloadMaterialOrSecrets() async throws {
        let context = makeContext()
        let store = ExplanationTraceStore()
        let client = ScriptedExplanationModelClient([
            .toolCall(ExplanationToolCall(name: "get_current_status", argumentsJSON: "{}")),
            .finalText("Done")
        ])
        let agent = makeAgent(client: client, trace: store)

        _ = try await agent.run(context: context, executor: makeExecutor(context: context), runID: knownRunID)

        let serialized = await store.recordedEvents()
            .map(Self.describe)
            .joined(separator: "\n")
        // No raw payloads, timestamps, or credential-shaped material in traces.
        #expect(!serialized.contains("sk-"))
        #expect(!serialized.contains("Authorization"))
        #expect(!serialized.contains("test-feed"))
        #expect(!serialized.contains(checkedAt.timeIntervalSince1970.description))
        #expect(!serialized.contains("{}"))
    }
}

private extension StatusExplanationAgentTests {
    static func describe(_ event: ExplanationTraceEvent) -> String {
        switch event {
        case let .runStarted(runID, regionID):
            "\(runID) started \(regionID)"
        case .contextBuilt:
            "contextBuilt"
        case let .modelRequested(runID, step):
            "\(runID) model \(step)"
        case let .toolRequested(runID, name):
            "\(runID) requested \(name)"
        case let .toolSucceeded(runID, name):
            "\(runID) ok \(name)"
        case let .toolFailed(runID, name, reason):
            "\(runID) failed \(name) \(reason)"
        case let .finalResponseValidated(runID):
            "\(runID) validated"
        case let .runCompleted(runID, modelTurns, toolCalls):
            "\(runID) completed \(modelTurns) \(toolCalls)"
        case let .frameworkRunCompleted(runID, toolCallCount):
            "\(runID) framework-completed \(toolCallCount)"
        case let .runFailed(runID, reason):
            "\(runID) failed \(reason)"
        case let .fallbackUsed(reason):
            "fallback \(reason)"
        case let .countryRunStarted(runID):
            "\(runID) country started"
        case let .countryCompleted(runID, modelTurns, toolCalls):
            "\(runID) country completed \(modelTurns) \(toolCalls)"
        case let .countryFailed(runID, reason):
            "\(runID) country failed \(reason)"
        }
    }
}

private extension [ExplanationTraceEvent] {
    func firstID() -> UUID? {
        first?.extractRunID
    }
}

private extension ExplanationTraceEvent {
    var extractRunID: UUID? {
        switch self {
        case let .runStarted(runID, _),
             let .contextBuilt(runID),
             let .modelRequested(runID, _),
             let .toolRequested(runID, _),
             let .toolSucceeded(runID, _),
             let .toolFailed(runID, _, _),
             let .finalResponseValidated(runID),
             let .runCompleted(runID, _, _),
             let .frameworkRunCompleted(runID, _),
             let .countryRunStarted(runID),
             let .countryCompleted(runID, _, _),
             let .countryFailed(runID, _),
             let .runFailed(runID, _):
            runID
        case .fallbackUsed:
            nil
        }
    }
}
