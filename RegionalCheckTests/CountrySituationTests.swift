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
        "empty-statuses",
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
}
