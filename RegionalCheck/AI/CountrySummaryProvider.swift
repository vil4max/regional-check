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
        source: \(ModelStatusSource.publicAlertFeed)
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

struct StatusDetailsInput: Sendable {
    let region: StatusExplanationInput
    let countryAggregate: CountrySituationAggregate
    let countryContext: CountrySituationContext
    let localeIdentifier: String
    let refreshRevision: Int
}

extension StatusDetailsInput: Equatable {
    static func == (lhs: StatusDetailsInput, rhs: StatusDetailsInput) -> Bool {
        lhs.region == rhs.region
            && lhs.countryAggregate == rhs.countryAggregate
            && lhs.countryContext.state == rhs.countryContext.state
            && lhs.countryContext.totalRegions == rhs.countryContext.totalRegions
            && lhs.countryContext.alertRegions == rhs.countryContext.alertRegions
            && lhs.countryContext.clearCount == rhs.countryContext.clearCount
            && lhs.countryContext.unavailableCount == rhs.countryContext.unavailableCount
            && lhs.countryContext.sourceRaw == rhs.countryContext.sourceRaw
            && lhs.countryContext.isSnapshotStale == rhs.countryContext.isSnapshotStale
            && lhs.localeIdentifier == rhs.localeIdentifier
            && lhs.refreshRevision == rhs.refreshRevision
    }
}

protocol StatusDetailsSummarizing: Sendable {
    func summary(for input: StatusDetailsInput) async throws -> String
}

struct DeterministicStatusDetailsProvider: StatusDetailsSummarizing {
    func summary(for input: StatusDetailsInput) async throws -> String {
        let language = Locale(identifier: input.localeIdentifier).language.languageCode?.identifier ?? "en"
        let regionLine = "\(input.region.region.title): \(input.region.status.explanation)"
        return [
            regionLine,
            countryLine(for: input, language: language),
            freshnessLine(isStale: input.countryContext.isSnapshotStale, language: language)
        ].joined(separator: "\n")
    }

    private func countryLine(for input: StatusDetailsInput, language: String) -> String {
        let aggregate = input.countryAggregate
        let affected = aggregate.alerts.prefix(3).map(\.title).joined(separator: ", ")
        switch language {
        case "ru":
            return russianCountryLine(aggregate: aggregate, affected: affected)
        case "uk":
            return ukrainianCountryLine(aggregate: aggregate, affected: affected)
        default:
            return englishCountryLine(aggregate: aggregate, affected: affected)
        }
    }

    private func englishCountryLine(aggregate: CountrySituationAggregate, affected: String) -> String {
        switch aggregate.state {
        case .noData:
            "Country: no regional status data available."
        case .allClear:
            "Country: all \(aggregate.totalRegions) regions report clear."
        case .partialCoverageNoAlerts:
            "Country: no active alerts in \(aggregate.clearCount) reporting regions."
        case .alertsActive:
            "Country: alerts in \(aggregate.alerts.count) of \(aggregate.totalRegions) regions: \(affected)."
        }
    }

    private func russianCountryLine(aggregate: CountrySituationAggregate, affected: String) -> String {
        switch aggregate.state {
        case .noData:
            "По стране: нет данных о статусе регионов."
        case .allClear:
            "По стране: во всех \(aggregate.totalRegions) регионах тревог нет."
        case .partialCoverageNoAlerts:
            "По стране: в \(aggregate.clearCount) регионах с данными активных тревог нет."
        case .alertsActive:
            "По стране: тревога в \(aggregate.alerts.count) из \(aggregate.totalRegions) регионов: \(affected)."
        }
    }

    private func ukrainianCountryLine(aggregate: CountrySituationAggregate, affected: String) -> String {
        switch aggregate.state {
        case .noData:
            "По країні: немає даних про статус регіонів."
        case .allClear:
            "По країні: у всіх \(aggregate.totalRegions) регіонах тривог немає."
        case .partialCoverageNoAlerts:
            "По країні: у \(aggregate.clearCount) регіонах із даними активних тривог немає."
        case .alertsActive:
            "По країні: тривога у \(aggregate.alerts.count) з \(aggregate.totalRegions) регіонів: \(affected)."
        }
    }

    private func freshnessLine(isStale: Bool, language: String) -> String {
        switch language {
        case "ru":
            isStale ? "Данные могут быть устаревшими." : "Данные актуальны."
        case "uk":
            isStale ? "Дані можуть бути застарілими." : "Дані актуальні."
        default:
            isStale ? "Data may be outdated." : "Data is current."
        }
    }
}

enum StatusDetailsInstructions {
    static let version = "2026-08-31"
    static let text = """
    You turn supplied regional and country alert facts into one concise summary.
    Rules you must follow:
    - Write every field only in requested_language.
    - The supplied regional phase and country situation_state are authoritative. Never re-classify them.
    - Cover both the selected region and the overall country situation.
    - State only counts and region names present in the facts.
    - Never claim the country or any region is safe. Never give travel, emergency, or safety advice.
    - Never predict future alerts or infer causes.
    - If data_stale is true, disclose that data may be outdated.
    - Return exactly three short fields: region, country, freshness.
    - Keep the entire result glanceable; no introductions, markdown, source names, or person names.
    """
}

@Generable
struct StatusDetailsDraft {
    @Guide(description: "One short sentence about the selected region")
    var regionSummary: String

    @Guide(description: "One short country sentence including affected regions when alerts are active")
    var countrySummary: String

    @Guide(description: "Freshness note; mentions possible outdatedness when data_stale is true")
    var freshnessNote: String
}

struct FoundationModelsStatusDetailsProvider: StatusDetailsSummarizing {
    static let limits = ExplanationRunLimits(
        maxModelTurns: 1,
        maxToolCalls: 0,
        maxFinalCharacters: 900,
        timeout: .seconds(20)
    )

    private let availability: @Sendable () -> SystemLanguageModel.Availability
    private let trace: (any ExplanationTraceRecording)?

    init(
        trace: (any ExplanationTraceRecording)?,
        availability: @escaping @Sendable () -> SystemLanguageModel.Availability = {
            SystemLanguageModel.default.availability
        }
    ) {
        self.trace = trace
        self.availability = availability
    }

    func summary(for input: StatusDetailsInput) async throws -> String {
        guard case .available = availability() else {
            throw ExplanationRunError.modelTransportFailed
        }

        let runID = UUID()
        await trace?.record(.countryRunStarted(runID: runID))
        let session = LanguageModelSession(
            model: .default,
            tools: [],
            instructions: StatusDetailsInstructions.text
        )

        do {
            let response = try await BoundedAwait.value(timeout: Self.limits.timeout) {
                try await session.respond(to: Self.promptFacts(for: input), generating: StatusDetailsDraft.self)
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
            let normalized = ExplanationTransportNormalizer.normalized(error)
                ?? ExplanationRunError.modelTransportFailed
            await trace?.record(.countryFailed(runID: runID, reason: normalized.traceReason))
            throw normalized
        }
    }

    static func promptFacts(for input: StatusDetailsInput) -> String {
        let affected = input.countryContext.alertRegions.map(\.title).joined(separator: ", ")
        return """
        requested_language: \(supportedLanguage(from: input.localeIdentifier))
        selected_region_id: \(input.region.region.rawValue)
        selected_region_title: \(input.region.region.title)
        selected_region_phase: \(input.region.status.phase)
        situation_state: \(input.countryContext.state.rawValue)
        total_regions: \(input.countryContext.totalRegions)
        active_alert_regions: \(input.countryContext.alertRegions.count)\(affected.isEmpty ? "" : " (\(affected))")
        clear_regions: \(input.countryContext.clearCount)
        regions_without_data: \(input.countryContext.unavailableCount)
        source: \(ModelStatusSource.publicAlertFeed)
        data_age_seconds: \(Int(input.countryContext.ageSeconds))
        data_stale: \(input.countryContext.isSnapshotStale)
        Produce one combined regional and country summary.
        """
    }

    static func assembled(_ draft: StatusDetailsDraft, limits: ExplanationRunLimits) throws -> String {
        let lines = [draft.regionSummary, draft.countrySummary, draft.freshnessNote]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count == 3 else { throw ExplanationRunError.invalidFinalOutput }
        return try ExplanationOutputValidator.validated(lines.joined(separator: "\n"), limits: limits).text
    }

    private static func supportedLanguage(from localeIdentifier: String) -> String {
        let language = Locale(identifier: localeIdentifier).language.languageCode?.identifier ?? "en"
        return ["en", "ru", "uk"].contains(language) ? language : "en"
    }
}

struct FallbackStatusDetailsProvider: StatusDetailsSummarizing {
    let primary: any StatusDetailsSummarizing
    let fallback: any StatusDetailsSummarizing
    var trace: (any ExplanationTraceRecording)?

    func summary(for input: StatusDetailsInput) async throws -> String {
        do {
            return try await primary.summary(for: input)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try CancellationPolicy.rethrowIfCallerCancelled(error)
            try Task.checkCancellation()
            let reason = (error as? ExplanationRunError)?.traceReason ?? "model_transport"
            await trace?.record(.fallbackUsed(reason: reason))
            return try await fallback.summary(for: input)
        }
    }
}
