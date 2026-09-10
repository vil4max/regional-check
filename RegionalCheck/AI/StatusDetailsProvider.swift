import DriveCheckKit
import Foundation
import FoundationModels

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
        let locale = Locale(identifier: input.localeIdentifier)
        var lines = [
            StatusDetailsLocalization.regionLine(for: input, locale: locale)
        ]
        if let nearbyWarning = StatusDetailsLocalization.nearbyWarning(for: input, locale: locale) {
            lines.append(nearbyWarning)
        }
        lines.append(StatusDetailsLocalization.countryLine(for: input, locale: locale))
        if let warning = StatusDetailsLocalization.staleWarning(
            isStale: input.countryContext.isSnapshotStale, locale: locale
        ) {
            lines.append(warning)
        }
        return lines.joined(separator: "\n")
    }
}

private enum StatusDetailsLocalization {
    static func regionLine(for input: StatusDetailsInput, locale: Locale) -> String {
        switch input.region.status.phase {
        case .quiet:
            localized("status.details.region_quiet", locale: locale)
        case .alarm:
            localized("status.details.region_alarm", locale: locale)
        case .idle, .error, .regionUnavailable:
            formatted(
                "status.details.region_format",
                input.region.region.title(locale: locale),
                input.region.status.explanation(locale: locale),
                locale: locale
            )
        }
    }

    static func nearbyWarning(for input: StatusDetailsInput, locale: Locale) -> String? {
        guard input.region.status.phase == .quiet else { return nil }
        let nearbyAlerts = NearbyRegionPolicy.activeAlerts(
            near: input.region.region,
            among: input.countryAggregate.alerts
        )
        guard !nearbyAlerts.isEmpty else { return nil }

        let shown = nearbyAlerts.prefix(2).map { $0.title(locale: locale) }.joined(separator: ", ")
        let remaining = nearbyAlerts.count - min(2, nearbyAlerts.count)
        if remaining > 0 {
            return formatted("status.details.nearby_alerts_more", shown, remaining, locale: locale)
        }
        return formatted("status.details.nearby_alerts", shown, locale: locale)
    }

    static func countryLine(for input: StatusDetailsInput, locale: Locale) -> String {
        let aggregate = input.countryAggregate
        switch aggregate.state {
        case .noData:
            return localized("country.summary.no_data", locale: locale)
        case .allClear:
            return formatted("country.summary.all_clear", aggregate.totalRegions, locale: locale)
        case .partialCoverageNoAlerts:
            return formatted("country.summary.partial_clear", aggregate.clearCount, locale: locale)
        case .alertsActive:
            return formatted(
                "country.summary.alerts_active",
                aggregate.alerts.count,
                aggregate.totalRegions,
                locale: locale
            )
        }
    }

    static func staleWarning(isStale: Bool, locale: Locale) -> String? {
        guard isStale else { return nil }
        return localized("country.summary.stale", locale: locale)
    }

    private static func formatted(
        _ key: String.LocalizationValue,
        _ arguments: CVarArg...,
        locale: Locale
    ) -> String {
        String(
            format: localized(key, locale: locale),
            locale: locale,
            arguments: arguments
        )
    }

    private static func localized(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, bundle: AppLocalization.bundle(for: locale), locale: locale)
    }
}

enum StatusDetailsInstructions {
    static let version = "2026-09-04"
    static let text = """
    You turn supplied country alert facts into one short, natural context sentence for a driver glancing at the screen.
    Swift renders the selected region status separately; do not restate or reinterpret it.
    Rules you must follow:
    - Write the field only in requested_language.
    - The supplied country situation_state is authoritative. Never re-classify it.
    - State only exact counts and region names present in the facts.
    - nearby_alert_regions is authoritative and already calculated by Swift.
    - When nearby_alert_regions is not empty and the selected region is quiet, begin with a brief attention warning.
    - Use the requested-language equivalent of "Be careful: an air raid alert is active in a nearby region."
    - Mention only nearby region names supplied in nearby_alert_regions.
    - When the selected region is quiet and other regions have alerts, describe them as other regions.
    - When the selected region has an alert, give the nationwide count without repeating its status.
    - Include up to three affected region names only when the sentence remains short.
    - Use plain conversational language.
    - Never claim the country or any region is safe. Never give travel, emergency, or safety advice.
    - Never predict future alerts, road closures, traffic conditions, or infer causes.
    - Return exactly one short country field.
    - Keep the result glanceable; no introductions, markdown, source names, or person names.
    """
}

@Generable
struct StatusDetailsDraft {
    @Guide(description: "One short country-context sentence with exact counts and up to three affected region names")
    var countrySummary: String
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
            let assembled = try Self.assembled(response.content, input: input, limits: Self.limits)
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
        nearby_alert_regions: \(nearbyFacts(for: input))
        clear_regions: \(input.countryContext.clearCount)
        regions_without_data: \(input.countryContext.unavailableCount)
        source: \(ModelStatusSource.publicAlertFeed)
        Produce one country-context sentence.
        """
    }

    static func assembled(
        _ draft: StatusDetailsDraft,
        input: StatusDetailsInput,
        limits: ExplanationRunLimits
    ) throws -> String {
        let countrySummary = draft.countrySummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !countrySummary.isEmpty else { throw ExplanationRunError.invalidFinalOutput }
        try validate(countrySummary: countrySummary, for: input)
        let locale = Locale(identifier: input.localeIdentifier)
        var lines = [
            StatusDetailsLocalization.regionLine(for: input, locale: locale),
            countrySummary
        ]
        if let warning = StatusDetailsLocalization.staleWarning(
            isStale: input.countryContext.isSnapshotStale,
            locale: locale
        ) {
            lines.append(warning)
        }
        return try ExplanationOutputValidator.validated(lines.joined(separator: "\n"), limits: limits).text
    }

    static func validate(countrySummary: String, for input: StatusDetailsInput) throws {
        let locale = Locale(identifier: input.localeIdentifier)
        let normalized = countrySummary
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .lowercased(with: locale)

        let forbiddenCountryStems = ["russia", "росси", "росі"]
        guard !forbiddenCountryStems.contains(where: normalized.contains) else {
            throw ExplanationRunError.invalidFinalOutput
        }

        let language = supportedLanguage(from: input.localeIdentifier)
        let ukraineStem = switch language {
        case "ru": "украин"
        case "uk": "україн"
        default: "ukraine"
        }
        let aggregate = input.countryAggregate
        switch aggregate.state {
        case .alertsActive:
            guard normalized.contains(String(aggregate.alerts.count)),
                  normalized.contains(String(aggregate.totalRegions)),
                  normalized.contains(ukraineStem)
            else {
                throw ExplanationRunError.invalidFinalOutput
            }
        case .allClear:
            guard normalized.contains(String(aggregate.totalRegions)),
                  normalized.contains(ukraineStem)
            else {
                throw ExplanationRunError.invalidFinalOutput
            }
        case .partialCoverageNoAlerts:
            guard normalized.contains(String(aggregate.clearCount)) else {
                throw ExplanationRunError.invalidFinalOutput
            }
        case .noData:
            break
        }

        let nearbyAlerts = NearbyRegionPolicy.activeAlerts(
            near: input.region.region,
            among: aggregate.alerts
        )
        guard !nearbyAlerts.isEmpty else { return }

        let attentionStem = switch language {
        case "ru": "вниматель"
        case "uk": "уважн"
        default: "be careful"
        }
        let mentionsNearbyRegion = nearbyAlerts.contains { region in
            let title = region.title(locale: locale)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
                .lowercased(with: locale)
            guard let firstWord = title.split(separator: " ").first else { return false }
            return normalized.contains(String(firstWord.prefix(6)))
        }
        guard normalized.contains(attentionStem), mentionsNearbyRegion else {
            throw ExplanationRunError.invalidFinalOutput
        }
    }

    private static func nearbyFacts(for input: StatusDetailsInput) -> String {
        let locale = Locale(identifier: input.localeIdentifier)
        let nearby = NearbyRegionPolicy.activeAlerts(
            near: input.region.region,
            among: input.countryAggregate.alerts
        )
        guard !nearby.isEmpty else { return "0" }
        let titles = nearby.map { $0.title(locale: locale) }.joined(separator: ", ")
        return "\(nearby.count) (\(titles))"
    }

    private static func supportedLanguage(from localeIdentifier: String) -> String {
        let language = Locale(identifier: localeIdentifier).language.languageCode?.identifier ?? "en"
        return ["en", "ru", "uk"].contains(language) ? language : "en"
    }
}
