import DriveCheckKit
import Foundation

private final class LocalizationBundleToken: NSObject {}

enum AppLocalization {
    static let bundle = Bundle(for: LocalizationBundleToken.self)

    static func bundle(for locale: Locale) -> Bundle {
        guard let languageCode = locale.language.languageCode?.identifier,
              let path = bundle.path(forResource: languageCode, ofType: "lproj"),
              let localizedBundle = Bundle(path: path)
        else {
            return bundle
        }
        return localizedBundle
    }
}

/// Swift-owned classification of the country situation. The model receives
/// this state and synthesizes wording; it never classifies the country itself.
enum CountrySituationState: String, Equatable, Sendable {
    case noData
    case allClear
    case partialCoverageNoAlerts
    case alertsActive
}

/// Canonical deterministic aggregation of one all-region snapshot.
/// Invariant: clearCount + alerts.count + unavailable.count == totalRegions.
struct CountrySituationAggregate: Equatable, Sendable {
    let totalRegions: Int
    let alerts: [AlertRegion]
    let unavailable: [AlertRegion]
    let clearCount: Int

    var state: CountrySituationState {
        if unavailable.count == totalRegions {
            return .noData
        }
        if alerts.isEmpty {
            return clearCount == totalRegions ? .allClear : .partialCoverageNoAlerts
        }
        return .alertsActive
    }
}

/// Model-facing projection of one region with an active alert.
struct CountryRegionFact: Equatable, Sendable {
    let id: String
    let title: String
}

/// Projection of country-level facts for the model.
/// The snapshot timestamp is deliberately absent: ageSeconds and
/// isSnapshotStale carry everything the model may state about freshness,
/// so it never does timestamp arithmetic itself.
struct CountrySituationContext: Equatable, Sendable {
    let state: CountrySituationState
    let totalRegions: Int
    let alertRegions: [CountryRegionFact]
    let clearCount: Int
    let unavailableCount: Int
    /// Verbatim snapshot source value. Display mapping happens only at the
    /// prompt/presentation boundary, never inside this projection.
    let sourceRaw: String
    let ageSeconds: TimeInterval
    let isSnapshotStale: Bool
}

/// Derives the country situation from application state using the same
/// business rules as the rest of the app (DataFreshness + RefreshPolicy).
/// The model summarizes these facts; it never determines them.
struct CountrySituationAggregator: Sendable {
    /// A missing snapshot means the feature is unavailable. An existing
    /// snapshot with no statuses is a real domain state: every region is
    /// reported as having no data — not as "no feature".
    func aggregate(snapshot: AlertsSnapshot?) -> CountrySituationAggregate? {
        guard let snapshot else { return nil }
        var alerts: [AlertRegion] = []
        var unavailable: [AlertRegion] = []
        var clearCount = 0
        for region in AlertRegion.allCases {
            switch snapshot.status(for: region) {
            case .alarm:
                alerts.append(region)
            case .quiet:
                clearCount += 1
            case nil:
                unavailable.append(region)
            }
        }
        return CountrySituationAggregate(
            totalRegions: AlertRegion.allCases.count,
            alerts: alerts,
            unavailable: unavailable,
            clearCount: clearCount
        )
    }

    func context(
        from aggregate: CountrySituationAggregate,
        snapshot: AlertsSnapshot,
        now: Date,
        refreshIntervalSeconds: TimeInterval
    ) -> CountrySituationContext {
        let age = max(0, now.timeIntervalSince(snapshot.checkedAt))
        return CountrySituationContext(
            state: aggregate.state,
            totalRegions: aggregate.totalRegions,
            alertRegions: aggregate.alerts.map { CountryRegionFact(id: $0.rawValue, title: $0.title) },
            clearCount: aggregate.clearCount,
            unavailableCount: aggregate.unavailable.count,
            sourceRaw: snapshot.source,
            ageSeconds: age,
            isSnapshotStale: DataFreshness.isStale(
                checkedAt: snapshot.checkedAt,
                now: now,
                refreshIntervalSeconds: refreshIntervalSeconds
            )
        )
    }

    /// Deterministic fallback summary used when the model is unavailable or
    /// fails. Correctness and compactness over prose.
    ///
    /// Headline rule encodes domain honesty:
    /// - zero coverage never claims an alert-free situation;
    /// - partial coverage claims "no active alerts" only about reporting regions;
    /// - full coverage may say all regions are clear.
    func fallbackSummary(
        from aggregate: CountrySituationAggregate,
        context: CountrySituationContext,
        locale: Locale = .current
    ) -> String {
        var lines: [String] = []
        if aggregate.unavailable.count == aggregate.totalRegions {
            lines.append(String(
                localized: "country.summary.no_data",
                bundle: AppLocalization.bundle(for: locale),
                locale: locale
            ))
            lines.append(formatted("country.summary.no_data_count", aggregate.unavailable.count, locale: locale))
        } else if aggregate.alerts.isEmpty {
            if aggregate.clearCount == aggregate.totalRegions {
                lines.append(formatted("country.summary.all_clear", aggregate.totalRegions, locale: locale))
            } else {
                lines.append(formatted("country.summary.partial_clear", aggregate.clearCount, locale: locale))
            }
        } else {
            lines.append(formatted(
                "country.summary.alerts_active",
                aggregate.alerts.count,
                aggregate.totalRegions,
                locale: locale
            ))
        }

        if !(aggregate.unavailable.count == aggregate.totalRegions) {
            var statusParts: [String] = []
            if aggregate.clearCount != 0 {
                statusParts.append(formatted("country.summary.clear_count", aggregate.clearCount, locale: locale))
            }
            if !aggregate.unavailable.isEmpty {
                statusParts.append(formatted(
                    "country.summary.no_data_count",
                    aggregate.unavailable.count,
                    locale: locale
                ))
            }
            if !statusParts.isEmpty {
                lines.append(statusParts.joined(separator: " · "))
            }
        }

        if !aggregate.alerts.isEmpty {
            let titles = aggregate.alerts.map { $0.title(locale: locale) }
            let shown = titles.prefix(3).joined(separator: ", ")
            let extra = titles.count - min(3, titles.count)
            lines.append(extra > 0
                ? formatted("country.summary.affected_more", shown, extra, locale: locale)
                : formatted("country.summary.affected", shown, locale: locale))
        }

        let ageText = Self.ageText(seconds: context.ageSeconds, locale: locale)
        let freshnessPrefix = context.isSnapshotStale
            ? String(localized: "country.summary.stale", bundle: AppLocalization.bundle(for: locale), locale: locale)
            : String(localized: "country.summary.current", bundle: AppLocalization.bundle(for: locale), locale: locale)
        var freshnessLine = "\(freshnessPrefix) · \(ageText)"
        let sourceLabel = StatusSourceLabel.displayName(for: context.sourceRaw)
        if !sourceLabel.isEmpty {
            freshnessLine += " · \(sourceLabel)"
        }
        lines.append(freshnessLine)

        return lines.joined(separator: "\n")
    }

    private func formatted(_ key: String.LocalizationValue, _ arguments: CVarArg..., locale: Locale) -> String {
        String(
            format: String(localized: key, bundle: AppLocalization.bundle(for: locale), locale: locale),
            locale: locale,
            arguments: arguments
        )
    }

    private static func ageText(seconds: TimeInterval, locale: Locale) -> String {
        if seconds < 60 {
            return String(
                localized: "country.summary.age_under_minute",
                bundle: AppLocalization.bundle(for: locale),
                locale: locale
            )
        }
        let minutes = max(1, Int(seconds / 60))
        return String(
            format: String(
                localized: "country.summary.age_minutes",
                bundle: AppLocalization.bundle(for: locale),
                locale: locale
            ),
            locale: locale,
            minutes
        )
    }
}
