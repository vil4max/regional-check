import DriveCheckKit
import Foundation

extension FoundationModelsStatusDetailsProvider {
    static func validate(countrySummary: String, for input: StatusDetailsInput) throws {
        let locale = Locale(identifier: input.localeIdentifier)
        let normalized = fold(countrySummary, locale: locale)

        let forbiddenCountryStems = ["russia", "росси", "росі"]
        guard !forbiddenCountryStems.contains(where: normalized.contains) else {
            throw ExplanationRunError.invalidFinalOutput
        }

        let language = supportedLanguage(from: input.localeIdentifier)
        let localizedStem =
            switch language {
            case "ru": "украин"
            case "uk": "україн"
            default: "ukraine"
            }
        let ukraineStem = fold(localizedStem, locale: locale)
        try validateCounts(in: normalized, aggregate: input.countryAggregate, ukraineStem: ukraineStem)

        let nearbyAlerts = NearbyRegionPolicy.activeAlerts(
            near: input.region.region,
            among: input.countryAggregate.alerts
        )
        guard !nearbyAlerts.isEmpty else { return }

        let attentionStem =
            switch language {
            case "ru": "вниматель"
            case "uk": "уважн"
            default: "be careful"
            }
        let mentionsNearbyRegion = nearbyAlerts.contains { region in
            let title = fold(region.title(locale: locale), locale: locale)
            guard let firstWord = title.split(separator: " ").first else { return false }
            return normalized.contains(String(firstWord.prefix(6)))
        }
        guard normalized.contains(attentionStem), mentionsNearbyRegion else {
            throw ExplanationRunError.invalidFinalOutput
        }
    }

    /// Stems and model text must be folded the same way: diacritic folding turns "ї" into "і".
    private static func fold(_ text: String, locale: Locale) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale).lowercased(with: locale)
    }

    /// Every number in the summary must be one of the aggregate's own counts, and the counts
    /// the state needs must appear as whole numbers ("25" does not stand for 2 or 5).
    private static func validateCounts(
        in normalized: String,
        aggregate: CountrySituationAggregate,
        ukraineStem: String
    ) throws {
        let numbers = Set(normalized.split { !$0.isASCII || !$0.isNumber }.compactMap { Int($0) })
        let allowed: Set = [
            aggregate.alerts.count, aggregate.totalRegions, aggregate.clearCount, aggregate.unavailable.count,
        ]
        let required: Set<Int>
        var needsCountryName = true
        switch aggregate.state {
        case .alertsActive:
            required = [aggregate.alerts.count, aggregate.totalRegions]
        case .allClear:
            required = [aggregate.totalRegions]
        case .partialCoverageNoAlerts:
            required = [aggregate.clearCount]
            needsCountryName = false
        case .noData:
            return
        }
        guard numbers.isSubset(of: allowed), required.isSubset(of: numbers),
            !needsCountryName || normalized.contains(ukraineStem)
        else {
            throw ExplanationRunError.invalidFinalOutput
        }
    }
}
