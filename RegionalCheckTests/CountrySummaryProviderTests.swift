import DriveCheckKit
import Foundation
import FoundationModels
@testable import RegionalCheck
import Testing

struct CountrySummaryProviderTests {
    private let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let aggregator = CountrySituationAggregator()

    // MARK: - Swift-owned state classification

    @Test(arguments: [
        ("noData", 0, 0, 25),
        ("allClear", 0, 25, 0),
        ("partialCoverageNoAlerts", 0, 20, 5),
        ("alertsActive", 4, 20, 1)
    ])
    func aggregateStateIsSwiftClassified(config: String, alerts: Int, clear: Int, unavailable: Int) throws {
        let total = 25
        let regions = Array(AlertRegion.allCases)
        var snapshotStatuses: [AlertRegion: AlertStatus] = [:]
        for (index, region) in regions.enumerated() {
            if index < alerts {
                snapshotStatuses[region] = .alarm
            } else if index < alerts + clear {
                snapshotStatuses[region] = .quiet
            }
        }
        let aggregate = try #require(aggregator.aggregate(snapshot: AlertsSnapshot(
            source: "feed",
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: snapshotStatuses
        )))
        #expect(aggregate.alerts.count == alerts)
        #expect(aggregate.clearCount == clear)
        #expect(aggregate.unavailable.count == unavailable)
        #expect(aggregate.state.rawValue == config)
    }

    // MARK: - Prompt serialization

    @Test
    func promptFactsCarryStateAndCounts_withoutTimestamps() throws {
        let rawSource = "Vadym Klymenko API (default)"
        let snapshot = makeSnapshot(alarms: [.kharkiv, .sumy], source: rawSource)
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: checkedAt.addingTimeInterval(600),
            refreshIntervalSeconds: 60
        )
        let facts = FoundationModelsCountrySummaryProvider.promptFacts(for: context)
        #expect(facts.contains("situation_state: alertsActive"))
        #expect(facts.contains("active_alert_regions: 2"))
        #expect(facts.contains("data_stale: true"))
        #expect(facts.contains("source: public_alert_feed"))
        #expect(!facts.contains(rawSource))
        // No timestamp surface for the model.
        #expect(!facts.contains("2026"))
        #expect(!facts.contains(String(Int(checkedAt.timeIntervalSince1970))))
    }

    // MARK: - Structured draft assembly and validation

    @Test
    func assemblyJoinsNonEmptyFieldsAndSkipsEmptyOnes() throws {
        let full = try FoundationModelsCountrySummaryProvider.assembled(
            CountrySummaryDraft(headline: "H", affectedSummary: "A", freshnessNote: "F"),
            limits: .test
        )
        #expect(full == "H\nA\nF")

        let withoutAffected = try FoundationModelsCountrySummaryProvider.assembled(
            CountrySummaryDraft(headline: "H", affectedSummary: "   ", freshnessNote: "F"),
            limits: .test
        )
        #expect(withoutAffected == "H\nF")
    }

    @Test
    func emptyHeadlineIsRejected() {
        #expect(throws: ExplanationRunError.invalidFinalOutput) {
            try FoundationModelsCountrySummaryProvider.assembled(
                CountrySummaryDraft(headline: "  ", affectedSummary: "", freshnessNote: ""),
                limits: .test
            )
        }
    }

    @Test
    func oversizedAssemblyIsRejected() {
        let long = String(repeating: "x", count: 701)
        #expect(throws: ExplanationRunError.invalidFinalOutput) {
            try FoundationModelsCountrySummaryProvider.assembled(
                CountrySummaryDraft(headline: long, affectedSummary: "", freshnessNote: ""),
                limits: .test
            )
        }
    }

    // MARK: - Availability gating + deterministic fallback integration

    @Test
    func unavailableModelDegradesToDeterministicSummaryWithTrace() async throws {
        let store = ExplanationTraceStore()
        let composite = FallbackCountrySummaryProvider(
            primary: FoundationModelsCountrySummaryProvider(
                trace: store,
                availability: { .unavailable(.deviceNotEligible) }
            ),
            fallback: DeterministicCountrySummaryProvider(),
            trace: store
        )
        let (snapshot, aggregate, context) = try scenario()

        // The product stays fully useful without Apple Intelligence.
        let result = try await composite.summary(for: aggregate, context: context)
        #expect(result == aggregator.fallbackSummary(from: aggregate, context: context))

        let events = await store.recordedEvents()
        // Gating precedes run tracing; only the fallback reason is recorded.
        #expect(events == [.fallbackUsed(reason: "model_transport")])
        _ = snapshot
    }

    @Test
    func cancellationPropagatesWithoutFallbackOrTrace() async throws {
        let store = ExplanationTraceStore()
        struct CancelledProvider: CountrySummarizing {
            func summary(for _: CountrySituationAggregate, context _: CountrySituationContext) async throws -> String {
                throw CancellationError()
            }
        }
        let composite = FallbackCountrySummaryProvider(
            primary: CancelledProvider(),
            fallback: DeterministicCountrySummaryProvider(),
            trace: store
        )
        let (_, aggregate, context) = try scenario()

        await #expect(throws: CancellationError.self) {
            try await composite.summary(for: aggregate, context: context)
        }
        let events = await store.recordedEvents()
        #expect(events.isEmpty)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        alarms: Set<AlertRegion>,
        source: String = "feed"
    ) -> AlertsSnapshot {
        var statuses: [AlertRegion: AlertStatus] = [:]
        for region in AlertRegion.allCases {
            statuses[region] = alarms.contains(region) ? .alarm : .quiet
        }
        return AlertsSnapshot(source: source, serverCachedAt: checkedAt, fetchedAt: checkedAt, statuses: statuses)
    }

    private func scenario() -> (AlertsSnapshot, CountrySituationAggregate, CountrySituationContext) {
        let snapshot = makeSnapshot(alarms: [.kharkiv])
        let aggregate = aggregator.aggregate(snapshot: snapshot)!
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: checkedAt.addingTimeInterval(60),
            refreshIntervalSeconds: 60
        )
        return (snapshot, aggregate, context)
    }
}

private extension ExplanationRunLimits {
    static var test: ExplanationRunLimits {
        ExplanationRunLimits(maxModelTurns: 1, maxToolCalls: 0, maxFinalCharacters: 700, timeout: .seconds(5))
    }
}
