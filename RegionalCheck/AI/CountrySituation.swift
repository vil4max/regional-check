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
}
