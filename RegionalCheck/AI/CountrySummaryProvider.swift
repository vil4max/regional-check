import DriveCheckKit
import Foundation
import FoundationModels

/// Country-level summary capability. Implementations receive Swift-classified
/// facts and return presentation text; none of them may re-classify state.
protocol CountrySummarizing: Sendable {
    func summary(
        for aggregate: CountrySituationAggregate,
        context: CountrySituationContext
    ) async throws -> String
}

/// Deterministic twin: the product stays useful without any model.
struct DeterministicCountrySummaryProvider: CountrySummarizing {
    private let aggregator = CountrySituationAggregator()

    func summary(
        for aggregate: CountrySituationAggregate,
        context: CountrySituationContext
    ) async throws -> String {
        aggregator.fallbackSummary(from: aggregate, context: context)
    }
}

/// Versioned synthesis instructions. The supplied situation_state is
/// authoritative; wording is the model's only job.
enum CountrySummaryInstructions {
    static let version = "2026-08-26"
    static let text = """
    You turn supplied country alert facts into a concise overview.
    Rules you must follow:
    - The supplied situation_state is authoritative. Never re-classify it.
    - State only counts and region names present in the facts.
    - Never claim the country or any region is safe. Never give travel,
      emergency, or safety advice. Never predict future alerts or infer causes.
    - If data_stale is true, disclose that data may be outdated.
    - Keep each field short; no introductions, no markdown.
    """
}

/// Guided-generation schema mirroring the deterministic information hierarchy.
/// Swift owns visual layout in slice 3; the model fills semantic fields only.
@Generable
struct CountrySummaryDraft {
    @Guide(description: "One short headline sentence reflecting situation_state")
    var headline: String

    @Guide(description: "Affected regions phrasing; empty string when there are no active alerts")
    var affectedSummary: String

    @Guide(description: "Freshness note; mentions possible outdatedness when data_stale is true")
    var freshnessNote: String
}

/// Live transport over Apple's on-device system model, reusing every runtime v1
/// guarantee: availability gating, BoundedAwait termination, cancellation
/// policy, shared validation, tracing. Zero tools by construction — the tool
/// list is empty, so nothing can be invoked.
struct FoundationModelsCountrySummaryProvider: CountrySummarizing {
    /// Tighter than regional explanations: target is 3–6 short lines.
    static let limits = ExplanationRunLimits(
        maxModelTurns: 4,
        maxToolCalls: 0,
        maxFinalCharacters: 700,
        timeout: .seconds(20)
    )

    private let availability: @Sendable () -> SystemLanguageModel.Availability
    private let trace: (any ExplanationTraceRecording)?

    init(
        trace: (any ExplanationTraceRecording)?,
        availability: @escaping @Sendable () -> SystemLanguageModel
            .Availability = { SystemLanguageModel.default.availability }
    ) {
        self.trace = trace
        self.availability = availability
    }

    func summary(
        for _: CountrySituationAggregate,
        context: CountrySituationContext
    ) async throws -> String {
        guard case .available = availability() else {
            throw ExplanationRunError.modelTransportFailed
        }

        let runID = UUID()
        await trace?.record(.countryRunStarted(runID: runID))
        let session = LanguageModelSession(
            model: .default,
            tools: [],
            instructions: CountrySummaryInstructions.text
        )

        do {
            let response = try await BoundedAwait.value(timeout: Self.limits.timeout) {
                try await session.respond(to: Self.promptFacts(for: context), generating: CountrySummaryDraft.self)
            }
            let assembled = try Self.assembled(response.content, limits: Self.limits)
            await trace?.record(.finalResponseValidated(runID: runID))
            await trace?.record(.countryCompleted(runID: runID, modelTurns: 1, toolCalls: 0))
            return assembled
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ExplanationRunError {
            await trace?.record(.countryFailed(runID: runID, reason: error.traceReason))
            throw error
        } catch {
            try CancellationPolicy.rethrowIfCallerCancelled(error)
            if let runError = ExplanationTransportNormalizer.normalized(error) {
                await trace?.record(.countryFailed(runID: runID, reason: runError.traceReason))
                throw runError
            }
            await trace?.record(.countryFailed(
                runID: runID,
                reason: ExplanationRunError.modelTransportFailed.traceReason
            ))
            throw ExplanationRunError.modelTransportFailed
        }
    }

    /// Compact factual serialization. No timestamps: ageSeconds and
    /// isSnapshotStale already carry freshness deterministically.
    static func promptFacts(for context: CountrySituationContext) -> String {
        let affected = context.alertRegions.map(\.title).joined(separator: ", ")
        return """
        situation_state: \(context.state.rawValue)
        total_regions: \(context.totalRegions)
        active_alert_regions: \(context.alertRegions.count)\(affected.isEmpty ? "" : " (\(affected))")
        clear_regions: \(context.clearCount)
        regions_without_data: \(context.unavailableCount)
        source: \(context.sourceRaw)
        data_age_seconds: \(Int(context.ageSeconds))
        data_stale: \(context.isSnapshotStale)
        Produce the country overview fields.
        """
    }

    /// Shared untrusted-boundary validation per field plus overall size cap.
    static func assembled(_ draft: CountrySummaryDraft, limits: ExplanationRunLimits) throws -> String {
        let trimmedHeadline = draft.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try ExplanationOutputValidator.validated(trimmedHeadline, limits: limits)
        let lines = [draft.headline, draft.affectedSummary, draft.freshnessNote]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let joined = try ExplanationOutputValidator.validated(lines.joined(separator: "\n"), limits: limits)
        return joined.text
    }
}

/// Composition-level fallback selection with identical cancellation discipline
/// to the regional composite: caller cancellation never becomes fallback text.
struct FallbackCountrySummaryProvider: CountrySummarizing {
    let primary: any CountrySummarizing
    let fallback: any CountrySummarizing
    var trace: (any ExplanationTraceRecording)?

    func summary(
        for aggregate: CountrySituationAggregate,
        context: CountrySituationContext
    ) async throws -> String {
        do {
            return try await primary.summary(for: aggregate, context: context)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try CancellationPolicy.rethrowIfCallerCancelled(error)
            try Task.checkCancellation()
            let reason = (error as? ExplanationRunError)?.traceReason ?? "model_transport"
            await trace?.record(.fallbackUsed(reason: reason))
            return try await fallback.summary(for: aggregate, context: context)
        }
    }
}
