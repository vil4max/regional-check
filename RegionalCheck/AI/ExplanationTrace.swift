// swiftlint:disable line_length
import Foundation
import os

enum ExplanationTraceEvent: Equatable, Hashable, Sendable {
    case runStarted(runID: UUID, regionID: String)
    case contextBuilt(runID: UUID)
    case modelRequested(runID: UUID, step: Int)
    case toolRequested(runID: UUID, name: String)
    case toolSucceeded(runID: UUID, name: String)
    case toolFailed(runID: UUID, name: String, reason: String)
    case finalResponseValidated(runID: UUID)
    /// Orchestrated transports only: model turns are well-defined there.
    case runCompleted(runID: UUID, modelTurns: Int, toolCalls: Int)
    /// Framework-scheduled transports (FoundationModels): internal model turns
    /// have no stable definition; only deterministic tool calls are counted.
    case frameworkRunCompleted(runID: UUID, toolCallCount: Int)
    case runFailed(runID: UUID, reason: String)
    case fallbackUsed(reason: String)

    // Country summary runs are distinguished from regional explanation runs
    // so traces can answer "which feature produced this run" without payloads.
    case countryRunStarted(runID: UUID)
    case countryCompleted(runID: UUID, modelTurns: Int, toolCalls: Int)
    case countryFailed(runID: UUID, reason: String)
}

/// Store-level identity. Semantic events may repeat verbatim (for example
/// repeated fallbacks), so presentation order relies on the monotonic
/// sequence instead of the event value itself.
struct StoredTraceEvent: Equatable, Hashable, Sendable {
    let sequence: UInt64
    let event: ExplanationTraceEvent
}

/// Records externally observable orchestration events only. Hidden model
/// reasoning is neither requested nor stored; no keys, coordinates, or raw
/// payloads ever enter the trace.
protocol ExplanationTraceRecording: Sendable {
    func record(_ event: ExplanationTraceEvent) async
}

actor ExplanationTraceStore: ExplanationTraceRecording {
    static let subsystem = "vil4max.RegionalCheck"
    static let category = "AIExplanation"

    private(set) var events: [StoredTraceEvent] = []
    private var nextSequence: UInt64 = 0
    private let logger = Logger(subsystem: ExplanationTraceStore.subsystem, category: ExplanationTraceStore.category)

    func record(_ event: ExplanationTraceEvent) {
        nextSequence += 1
        events.append(StoredTraceEvent(sequence: nextSequence, event: event))
        log(event)
    }

    func storedEvents() -> [StoredTraceEvent] {
        events
    }

    func recordedEvents() -> [ExplanationTraceEvent] {
        events.map(\.event)
    }

    func reset() {
        events = []
    }

    /// Semantic OSLog output: identifiers, step numbers, tool names, categories.
    private func log(_ event: ExplanationTraceEvent) {
        switch event {
        case let .runStarted(runID, regionID):
            logger.info("run \(runID.uuidString, privacy: .public) started region=\(regionID, privacy: .public)")
        case .contextBuilt:
            break
        case let .modelRequested(runID, step):
            logger.debug("run \(runID.uuidString, privacy: .public) model turn=\(step, privacy: .public)")
        case let .toolRequested(runID, name):
            logger.debug("run \(runID.uuidString, privacy: .public) tool request=\(name, privacy: .public)")
        case let .toolSucceeded(runID, name):
            logger.debug("run \(runID.uuidString, privacy: .public) tool ok=\(name, privacy: .public)")
        case let .toolFailed(runID, name, reason):
            logger
                .notice(
                    "run \(runID.uuidString, privacy: .public) tool failed=\(name, privacy: .public) reason=\(reason, privacy: .public)"
                )
        case .finalResponseValidated:
            break
        case let .runCompleted(runID, modelTurns, toolCalls):
            logger
                .info(
                    "run \(runID.uuidString, privacy: .public) completed turns=\(modelTurns, privacy: .public) tools=\(toolCalls, privacy: .public)"
                )
        case let .frameworkRunCompleted(runID, toolCallCount):
            logger
                .info(
                    "run \(runID.uuidString, privacy: .public) framework-completed tools=\(toolCallCount, privacy: .public)"
                )
        case let .runFailed(runID, reason):
            logger.notice("run \(runID.uuidString, privacy: .public) failed reason=\(reason, privacy: .public)")
        case let .fallbackUsed(reason):
            logger.notice("explanation fallback used reason=\(reason, privacy: .public)")
        case let .countryRunStarted(runID):
            logger.info("country run \(runID.uuidString, privacy: .public) started")
        case let .countryCompleted(runID, modelTurns, toolCalls):
            logger
                .info(
                    "country run \(runID.uuidString, privacy: .public) completed turns=\(modelTurns, privacy: .public) tools=\(toolCalls, privacy: .public)"
                )
        case let .countryFailed(runID, reason):
            logger.notice("country run \(runID.uuidString, privacy: .public) failed reason=\(reason, privacy: .public)")
        }
    }
}
