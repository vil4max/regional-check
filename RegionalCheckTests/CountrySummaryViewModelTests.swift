import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct CountrySummaryViewModelTests {
    private let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Test doubles (continuation-based, mirroring ExplanationProviderSpy)

    actor SummarySpy: CountrySummarizing {
        struct StubError: Error {}

        private var pending: [CheckedContinuation<String, any Error>] = []
        private var receivedInputs: [(aggregate: CountrySituationAggregate, context: CountrySituationContext)] = []
        private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

        func summary(
            for aggregate: CountrySituationAggregate,
            context: CountrySituationContext
        ) async throws -> String {
            receivedInputs.append((aggregate, context))
            return try await withCheckedThrowingContinuation { continuation in
                pending.append(continuation)
                resumeSatisfied()
            }
        }

        func resolve(_ result: Result<String, any Error>) {
            precondition(!pending.isEmpty)
            pending.removeFirst().resume(with: result)
        }

        func waitUntilPending(count: Int = 1) async {
            guard pending.count < count else { return }
            await withCheckedContinuation { continuation in
                waiters.append((count, continuation))
            }
        }

        func requestCount() -> Int {
            receivedInputs.count
        }

        private func resumeSatisfied() {
            let satisfied = waiters.filter { pending.count >= $0.count }
            waiters.removeAll { pending.count >= $0.count }
            satisfied.forEach { $0.continuation.resume() }
        }
    }

    @MainActor
    final class SourceMock: ExplanationStatusContext {
        var lastSnapshot: AlertsSnapshot?
        var currentRegion: AlertRegion = .kyivCity
        var state: StatusState = .quiet(lastCheckedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private struct SUT {
        let viewModel: CountrySummaryViewModel
        let source: SourceMock
        let spy: SummarySpy
    }

    private func makeSUT(
        snapshot: AlertsSnapshot?,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_700_000_060) }
    ) -> SUT {
        let source = SourceMock()
        source.lastSnapshot = snapshot
        source.state = .quiet(lastCheckedAt: checkedAt)
        let spy = SummarySpy()
        let viewModel = CountrySummaryViewModel(
            summarizer: spy,
            source: source,
            now: now,
            refreshInterval: { 60 }
        )
        return SUT(viewModel: viewModel, source: source, spy: spy)
    }

    private func makeSnapshot(alarms: Set<AlertRegion> = [], statusesEmpty: Bool = false) -> AlertsSnapshot {
        var statuses: [AlertRegion: AlertStatus] = [:]
        if !statusesEmpty {
            for region in AlertRegion.allCases {
                statuses[region] = alarms.contains(region) ? .alarm : .quiet
            }
        }
        return AlertsSnapshot(
            source: "feed",
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: statuses
        )
    }

    // MARK: - Acceptance coverage

    /// Criterion 2: no snapshot → action unavailable.
    @Test
    func unavailableWithoutSnapshot() {
        let sut = makeSUT(snapshot: nil)
        #expect(!sut.viewModel.canRequestSummary)
        sut.viewModel.requestSummary()
        #expect(sut.viewModel.presentationState == .idle)
    }

    /// Criteria 3+6: request works purely from the existing snapshot and the
    /// deterministic provider path renders structured rows.
    @Test
    func deterministicPathRendersStructuredRowsWithoutNetwork() async throws {
        let snapshot = makeSnapshot(alarms: [.kharkiv])
        let source = SourceMock()
        source.lastSnapshot = snapshot
        source.state = .quiet(lastCheckedAt: checkedAt)
        let aggregator = CountrySituationAggregator()
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: checkedAt.addingTimeInterval(30),
            refreshIntervalSeconds: 60
        )
        let deterministic = DeterministicCountrySummaryProvider()

        let text = try await deterministic.summary(for: aggregate, context: context)
        let rows = text.split(separator: "\n").map(String.init)
        #expect(rows.first?.hasPrefix("Alerts active: 1 of 25") == true)
        #expect(rows.count == 4)
        // State distinction survives into presentation.
        #expect(rows[0] != makeAllClearFirstRow())
    }

    private func makeAllClearFirstRow() -> String {
        "All 25 regions report clear"
    }

    /// Criterion 4 (re-tap): single-flight taps never create parallel runs.
    @Test
    func repeatedTapsDoNotCreateConcurrentRequests() async {
        let sut = makeSUT(snapshot: makeSnapshot())
        sut.viewModel.requestSummary()
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending()
        #expect(await sut.spy.requestCount() == 1)
        #expect(sut.viewModel.presentationState == .loading)
        await sut.spy.resolve(.success("H\nF"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["H", "F"]))
    }

    @Test
    func elapsedTimeDoesNotDiscardCurrentResult() async {
        var currentTime = checkedAt.addingTimeInterval(10)
        let sut = makeSUT(snapshot: makeSnapshot(), now: { currentTime })
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending()

        currentTime = checkedAt.addingTimeInterval(20)
        await sut.spy.resolve(.success("Current result"))
        await drain()

        #expect(sut.viewModel.presentationState == .result(["Current result"]))
    }

    @Test
    func newerSnapshotWithSameFactsInvalidatesDeliveredResult() async {
        let sut = makeSUT(snapshot: makeSnapshot())
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending()
        await sut.spy.resolve(.success("Old result"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["Old result"]))

        sut.source.lastSnapshot = makeSnapshot().with(checkedAt: checkedAt.addingTimeInterval(60))
        sut.viewModel.synchronizeWithCurrentContext()

        #expect(sut.viewModel.presentationState == .idle)
    }

    /// Criterion 4 (facts changed): a newer snapshot cancels and discards.
    @Test
    func snapshotChangeCancelsRunAndDropsObsoleteResult() async {
        let sut = makeSUT(snapshot: makeSnapshot())
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending()

        sut.source.lastSnapshot = makeSnapshot(alarms: [.kharkiv]).with(checkedAt: checkedAt.addingTimeInterval(90))
        sut.viewModel.synchronizeWithCurrentContext()
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending(count: 2)

        await sut.spy.resolve(.success("Obsolete"))
        await drain()
        #expect(sut.viewModel.presentationState == .loading)

        await sut.spy.resolve(.success("Current\nRows"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["Current", "Rows"]))
    }

    /// Criterion 4 (leave screen): exit cancels without surfacing an error.
    @Test
    func leavingScreenCancelsActiveRunSilently() async {
        let sut = makeSUT(snapshot: makeSnapshot())
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending()
        sut.viewModel.cancelActiveRequest()
        await drain()
        #expect(sut.viewModel.presentationState == .idle)

        await sut.spy.resolve(.success("Late"))
        await drain()
        #expect(sut.viewModel.presentationState == .idle)
    }

    @Test
    func dismissingDeliveredResultReturnsToIdle() async {
        let sut = makeSUT(snapshot: makeSnapshot())
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending()
        await sut.spy.resolve(.success("Visible result"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["Visible result"]))

        sut.viewModel.dismissSummary()

        #expect(sut.viewModel.presentationState == .idle)
    }

    /// Failure path: error state with retry; alert domain untouched.
    @Test
    func failureShowsErrorAndRetryRecovers() async {
        let sut = makeSUT(snapshot: makeSnapshot())
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending()
        await sut.spy.resolve(.failure(SummarySpy.StubError()))
        await drain()
        #expect(sut.viewModel.presentationState == .error)

        sut.viewModel.retrySummary()
        await sut.spy.waitUntilPending(count: 1)
        await sut.spy.resolve(.success("Recovered row"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["Recovered row"]))
    }

    /// Criterion 10 at logic level: no history — a new run starts clean.
    @Test
    func noConversationMemoryBetweenRuns() async {
        let sut = makeSUT(snapshot: makeSnapshot())
        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending()
        await sut.spy.resolve(.success("First"))
        await drain()

        sut.source.lastSnapshot = makeSnapshot(alarms: [.odesa]).with(checkedAt: checkedAt.addingTimeInterval(120))
        sut.viewModel.synchronizeWithCurrentContext()
        #expect(sut.viewModel.presentationState == .idle)

        sut.viewModel.requestSummary()
        await sut.spy.waitUntilPending(count: 1)
        await sut.spy.resolve(.success("Second"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["Second"]))
        #expect(await sut.spy.requestCount() == 2)
    }

    private func drain() async {
        await Task.yield()
        await Task.yield()
    }
}

private extension AlertsSnapshot {
    func with(checkedAt: Date) -> AlertsSnapshot {
        AlertsSnapshot(source: source, serverCachedAt: checkedAt, fetchedAt: fetchedAt, statuses: statuses)
    }
}
