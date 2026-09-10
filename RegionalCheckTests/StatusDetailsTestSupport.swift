// swiftlint:disable force_unwrapping
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// Shared harness for status-details and country-summary presentation tests.
@MainActor
enum StatusDetailsTestSupport {
    static let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)

    struct SUT {
        let viewModel: StatusDetailsViewModel
        let source: SourceMock
        let spy: SummarizerSpy
    }

    actor SummarizerSpy: StatusDetailsSummarizing {
        private var inputs: [StatusDetailsInput] = []
        private var pending: [CheckedContinuation<String, any Error>] = []
        private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

        func summary(for input: StatusDetailsInput) async throws -> String {
            inputs.append(input)
            return try await withCheckedThrowingContinuation { continuation in
                pending.append(continuation)
                resumeWaiters()
            }
        }

        func waitUntilPending(_ count: Int = 1) async {
            guard pending.count < count else { return }
            await withCheckedContinuation { continuation in
                waiters.append((count, continuation))
            }
        }

        func resolve(_ result: Result<String, any Error>) {
            pending.removeFirst().resume(with: result)
        }

        func requestCount() -> Int {
            inputs.count
        }

        func receivedInputs() -> [StatusDetailsInput] {
            inputs
        }

        private func resumeWaiters() {
            let ready = waiters.filter { pending.count >= $0.0 }
            waiters.removeAll { pending.count >= $0.0 }
            ready.forEach { $0.1.resume() }
        }
    }

    @MainActor
    final class SourceMock: ExplanationStatusContext {
        var lastSnapshot: AlertsSnapshot?
        var currentRegion: AlertRegion = .kyivCity
        var state: StatusState = .quiet(lastCheckedAt: Date(timeIntervalSince1970: 1_700_000_000))
        var statusDetailsRevision: Int? = 0
    }

    static func makeSUT(
        alarms: Set<AlertRegion> = [],
        locale: Locale = Locale(identifier: "en"),
        now: @escaping () -> Date? = { nil }
    ) -> SUT {
        let source = SourceMock()
        source.lastSnapshot = makeSnapshot(alarms: alarms)
        let spy = SummarizerSpy()
        let viewModel = StatusDetailsViewModel(
            summarizer: spy,
            source: source,
            now: { now() ?? checkedAt.addingTimeInterval(30) },
            refreshInterval: { 60 },
            locale: { locale }
        )
        return SUT(viewModel: viewModel, source: source, spy: spy)
    }

    static func makeInput(
        localeIdentifier: String,
        rawSource: String,
        alarms: Set<AlertRegion> = [],
        age: TimeInterval = 30
    ) -> StatusDetailsInput {
        let snapshot = makeSnapshot(alarms: alarms, source: rawSource)
        let aggregator = CountrySituationAggregator()
        let aggregate = aggregator.aggregate(snapshot: snapshot)!
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: checkedAt.addingTimeInterval(age),
            refreshIntervalSeconds: 60
        )
        return StatusDetailsInput(
            region: StatusExplanationInput(
                snapshot: snapshot,
                region: .kyivCity,
                status: .quiet(lastCheckedAt: checkedAt)
            ),
            countryAggregate: aggregate,
            countryContext: context,
            localeIdentifier: localeIdentifier,
            refreshRevision: 0
        )
    }

    static func makeSnapshot(
        alarms: Set<AlertRegion> = [],
        source: String = "feed"
    ) -> AlertsSnapshot {
        AlertsSnapshot(
            source: source,
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: Dictionary(uniqueKeysWithValues: AlertRegion.allCases.map {
                ($0, alarms.contains($0) ? .alarm : .quiet)
            })
        )
    }

    static func drain() async {
        await Task.yield()
        await Task.yield()
    }
}
