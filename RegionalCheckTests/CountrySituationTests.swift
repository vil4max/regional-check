import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct CountrySituationTests {
    private let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let now = Date(timeIntervalSince1970: 1_700_000_060)
    private let interval: TimeInterval = 60

    private func makeSnapshot(
        alarms: Set<AlertRegion> = [],
        quiet: Set<AlertRegion> = [.kyivCity, .lviv],
        omit: Set<AlertRegion> = [],
        source: String = "device-feed",
        statusesEmpty: Bool = false,
        checkedAt stamp: Date? = nil
    ) -> AlertsSnapshot {
        var statuses: [AlertRegion: AlertStatus] = [:]
        if !statusesEmpty {
            for region in AlertRegion.allCases where !omit.contains(region) {
                statuses[region] = alarms.contains(region) ? .alarm : .quiet
            }
            for region in quiet where !omit.contains(region) && !alarms.contains(region) {
                statuses[region] = .quiet
            }
        }
        return AlertsSnapshot(
            source: source,
            serverCachedAt: stamp ?? checkedAt,
            fetchedAt: stamp ?? checkedAt,
            statuses: statuses
        )
    }

    // MARK: - Invariant

    @Test(arguments: [
        "all-clear",
        "single-alarm",
        "many-alarms",
        "with-missing",
        "empty-statuses"
    ])
    func countInvariantHoldsAcrossConfigurations(config: String) throws {
        let aggregator = CountrySituationAggregator()
        let snapshot: AlertsSnapshot
        switch config {
        case "all-clear":
            snapshot = makeSnapshot()
        case "single-alarm":
            snapshot = makeSnapshot(alarms: [.kharkiv])
        case "many-alarms":
            snapshot = makeSnapshot(alarms: [.kharkiv, .sumy, .donetsk, .odesa])
        case "with-missing":
            snapshot = makeSnapshot(alarms: [.kharkiv], omit: [.luhansk, .cherkasy])
        case "empty-statuses":
            snapshot = makeSnapshot(statusesEmpty: true)
        default:
            fatalError("unknown config")
        }
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        #expect(aggregate.clearCount + aggregate.alerts.count + aggregate.unavailable.count == aggregate.totalRegions)
    }

    // MARK: - Aggregation semantics

    @Test
    func allClearAggregateCounts() throws {
        let aggregator = CountrySituationAggregator()
        let aggregate = try #require(aggregator.aggregate(snapshot: makeSnapshot()))
        #expect(aggregate.alerts.isEmpty)
        #expect(aggregate.unavailable.isEmpty)
        #expect(aggregate.clearCount == 25)
        #expect(aggregate.totalRegions == 25)
    }

    @Test
    func emptyStatusesSnapshotMeansAllRegionsHaveNoData() throws {
        let aggregator = CountrySituationAggregator()
        let aggregate = try #require(aggregator.aggregate(snapshot: makeSnapshot(statusesEmpty: true)))
        #expect(aggregate.alerts.isEmpty)
        #expect(aggregate.clearCount == 0)
        #expect(aggregate.unavailable.count == 25)
    }

    @Test
    func missingRegionsAreUnavailableAndOrderIsCanonical() throws {
        let aggregator = CountrySituationAggregator()
        let aggregate = try #require(
            aggregator.aggregate(snapshot: makeSnapshot(alarms: [.sumy, .kharkiv], omit: [.odesa]))
        )
        // AlertRegion.allCases canonical order places sumy before kharkiv.
        #expect(aggregate.alerts == [.sumy, .kharkiv])
        #expect(aggregate.unavailable == [.odesa])
        #expect(aggregate.clearCount == 22)
    }

    @Test
    func nilSnapshotMeansFeatureUnavailable() {
        let aggregator = CountrySituationAggregator()
        #expect(aggregator.aggregate(snapshot: nil) == nil)
    }

    @Test
    func snapshotIsNeverMutated() throws {
        let aggregator = CountrySituationAggregator()
        let snapshot = makeSnapshot(alarms: [.kharkiv])
        let before = snapshot
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        _ = aggregator.context(from: aggregate, snapshot: snapshot, now: now, refreshIntervalSeconds: interval)
        _ = aggregator.fallbackSummary(
            from: aggregate,
            context: aggregator.context(from: aggregate, snapshot: snapshot, now: now, refreshIntervalSeconds: interval)
        )
        #expect(snapshot == before)
    }

    // MARK: - Model-facing projection

    @Test
    func contextContainsExactlyTheApprovedFields_withoutTimestamp() throws {
        let aggregator = CountrySituationAggregator()
        let aggregate = try #require(aggregator.aggregate(snapshot: makeSnapshot(alarms: [.kharkiv])))
        let context = aggregator.context(
            from: aggregate,
            snapshot: makeSnapshot(alarms: [.kharkiv]),
            now: now,
            refreshIntervalSeconds: interval
        )
        // Full-value equality pins the field set: no timestamp, no extra state.
        #expect(context == CountrySituationContext(
            state: .alertsActive,
            totalRegions: 25,
            alertRegions: [CountryRegionFact(id: "kharkiv", title: AlertRegion.kharkiv.title)],
            clearCount: 24,
            unavailableCount: 0,
            sourceRaw: "device-feed",
            ageSeconds: 60,
            isSnapshotStale: false
        ))
    }

    @Test
    func stalenessReusesDomainRuleBoundary() throws {
        let aggregator = CountrySituationAggregator()
        let aggregate = try #require(aggregator.aggregate(snapshot: makeSnapshot()))

        let fresh = aggregator.context(
            from: aggregate,
            snapshot: makeSnapshot(),
            now: checkedAt.addingTimeInterval(interval * 2),
            refreshIntervalSeconds: interval
        )
        let stale = aggregator.context(
            from: aggregate,
            snapshot: makeSnapshot(),
            now: checkedAt.addingTimeInterval(interval * 2 + 1),
            refreshIntervalSeconds: interval
        )
        #expect(!fresh.isSnapshotStale)
        #expect(stale.isSnapshotStale)
    }

    @Test
    func futureCheckedAtClampsAgeToZero() throws {
        let aggregator = CountrySituationAggregator()
        let aggregate = try #require(aggregator.aggregate(snapshot: makeSnapshot()))
        let context = aggregator.context(
            from: aggregate,
            snapshot: makeSnapshot(),
            now: checkedAt.addingTimeInterval(-30),
            refreshIntervalSeconds: interval
        )
        #expect(context.ageSeconds == 0)
    }

    // MARK: - Deterministic fallback text

    @Test
    func fallbackAllClearFresh() throws {
        let aggregator = CountrySituationAggregator()
        let snapshot = makeSnapshot(source: "test")
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: now,
            refreshIntervalSeconds: interval
        )
        let text = aggregator.fallbackSummary(from: aggregate, context: context)
        #expect(text.contains("All 25 regions report clear"))
        #expect(!text.contains("outdated"))
    }

    @Test
    func fallbackWithAlertsShowsCountsAffectedAndFreshnessSeparately() throws {
        let aggregator = CountrySituationAggregator()
        let snapshot = makeSnapshot(alarms: [.kharkiv, .sumy, .donetsk, .odesa], omit: [.luhansk])
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        let staleContext = aggregator.context(
            from: aggregate,
            snapshot: makeSnapshot(alarms: [.kharkiv]),
            now: checkedAt.addingTimeInterval(600),
            refreshIntervalSeconds: interval
        )
        let text = aggregator.fallbackSummary(from: aggregate, context: staleContext)
        #expect(text.contains("Alerts active: 4 of 25 regions"))
        #expect(text.contains("Clear: 20 · No data: 1"))
        let affectedLine = try #require(text.split(separator: "\n").first { $0.hasPrefix("Affected:") })
        #expect(affectedLine.hasSuffix("+1"))
        #expect(text.hasPrefix("Alerts active:"))
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines.count == 4)
        #expect(lines[3].hasPrefix("Data may be outdated · 10 min old"))
    }

    @Test
    func fallbackAffectedListCapsAtThreeWithRemainder() throws {
        let aggregator = CountrySituationAggregator()
        let alarms: Set<AlertRegion> = [.kharkiv, .sumy, .donetsk, .odesa, .lviv]
        let snapshot = makeSnapshot(alarms: alarms)
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: now,
            refreshIntervalSeconds: interval
        )
        let text = aggregator.fallbackSummary(from: aggregate, context: context)
        let affectedLine = try #require(text.split(separator: "\n").first { $0.hasPrefix("Affected:") })
        let remainder = Int(affectedLine.split(separator: "+")[1]) ?? 0
        #expect(remainder == 2)
    }

    @Test
    func fallbackZeroCoverageStatesDataUnavailability_neverAlertFreedom() throws {
        let aggregator = CountrySituationAggregator()
        let snapshot = makeSnapshot(statusesEmpty: true)
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: now,
            refreshIntervalSeconds: interval
        )
        let text = aggregator.fallbackSummary(from: aggregate, context: context)
        #expect(text.contains("No regional status data available"))
        #expect(text.contains("No data: 25"))
        // Zero coverage must never make any alert-freedom or clear claim.
        #expect(!text.lowercased().contains("clear"))
        #expect(!text.contains("No active alerts"))
    }

    @Test
    func fallbackPartialCoverageLimitsClearClaimToReportingRegions() throws {
        let aggregator = CountrySituationAggregator()
        let snapshot = makeSnapshot(omit: [.odesa, .lviv, .kharkiv, .sumy, .donetsk])
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        #expect(aggregate.clearCount == 20)
        #expect(aggregate.unavailable.count == 5)
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: now,
            refreshIntervalSeconds: interval
        )
        let text = aggregator.fallbackSummary(from: aggregate, context: context)
        #expect(text.contains("No active alerts in 20 reporting regions"))
        #expect(text.contains("No data: 5"))
        #expect(!text.contains("All 25 regions report clear"))
    }
}
