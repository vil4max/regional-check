import Foundation
import os

enum ExplanationTraceEvent: Equatable, Hashable, Sendable {
    case finalResponseValidated(runID: UUID)
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

    /// Semantic OSLog output: identifiers, counts and failure categories.
    private func log(_ event: ExplanationTraceEvent) {
        switch event {
        case .finalResponseValidated:
            break
        case let .fallbackUsed(reason):
            logger.notice("explanation fallback used reason=\(reason, privacy: .public)")
        case let .countryRunStarted(runID):
            logger.info("country run \(runID.uuidString, privacy: .public) started")
        case let .countryCompleted(runID, modelTurns, toolCalls):
            logger.info(
                """
                country run \(runID.uuidString, privacy: .public) completed \
                turns=\(modelTurns, privacy: .public) tools=\(toolCalls, privacy: .public)
                """
            )
        case let .countryFailed(runID, reason):
            logger.notice(
                "country run \(runID.uuidString, privacy: .public) failed reason=\(reason, privacy: .public)"
            )
        }
    }
}
