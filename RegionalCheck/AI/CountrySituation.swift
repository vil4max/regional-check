import DriveCheckKit
import Foundation

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
        context: CountrySituationContext
    ) -> String {
        var lines: [String] = []
        if aggregate.unavailable.count == aggregate.totalRegions {
            lines.append("No regional status data available")
            lines.append("No data: \(aggregate.unavailable.count)")
        } else if aggregate.alerts.isEmpty {
            if aggregate.clearCount == aggregate.totalRegions {
                lines.append("All \(aggregate.totalRegions) regions report clear")
            } else {
                lines.append("No active alerts in \(aggregate.clearCount) reporting regions")
            }
        } else {
            lines.append("Alerts active: \(aggregate.alerts.count) of \(aggregate.totalRegions) regions")
        }

        if !(aggregate.unavailable.count == aggregate.totalRegions) {
            var statusParts: [String] = []
            if aggregate.clearCount != 0 {
                statusParts.append("Clear: \(aggregate.clearCount)")
            }
            if !aggregate.unavailable.isEmpty {
                statusParts.append("No data: \(aggregate.unavailable.count)")
            }
            if !statusParts.isEmpty {
                lines.append(statusParts.joined(separator: " · "))
            }
        }

        if !aggregate.alerts.isEmpty {
            let titles = aggregate.alerts.map(\.title)
            let shown = titles.prefix(3).joined(separator: ", ")
            let extra = titles.count - min(3, titles.count)
            lines.append(extra > 0 ? "Affected: \(shown) +\(extra)" : "Affected: \(shown)")
        }

        let ageText = Self.ageText(seconds: context.ageSeconds)
        let freshnessPrefix = context.isSnapshotStale ? "Data may be outdated" : "Data is current"
        var freshnessLine = "\(freshnessPrefix) · \(ageText)"
        let sourceLabel = StatusSourceLabel.displayName(for: context.sourceRaw)
        if !sourceLabel.isEmpty {
            freshnessLine += " · \(sourceLabel)"
        }
        lines.append(freshnessLine)

        return lines.joined(separator: "\n")
    }

    private static func ageText(seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "under a minute old"
        }
        let minutes = max(1, Int(seconds / 60))
        return "\(minutes) min old"
    }
}
