import DriveCheckKit
import Foundation
import Observation

/// Owns the async status-details presentation state.
/// Mirrors the proven explanation lifecycle: immutable input per run,
/// generation token, single-flight taps, obsolete results never displayed.
/// A deterministic baseline is published immediately, then enhanced by the
/// model within a bounded timeout; the baseline remains when enhancement fails.
@MainActor
@Observable
final class StatusDetailsViewModel {
    enum PresentationState: Equatable {
        case idle
        case loading
        case result([String])
        case error
    }

    private struct SemanticKey: Equatable {
        let region: AlertRegion
        let phase: StatusState.Phase
        let countryState: CountrySituationState
        let totalRegions: Int
        let alertRegions: [CountryRegionFact]
        let clearCount: Int
        let unavailableCount: Int
        let sourceRaw: String
        let isSnapshotStale: Bool
        let localeIdentifier: String

        init(input: StatusDetailsInput) {
            region = input.region.region
            phase = input.region.status.phase
            countryState = input.countryContext.state
            totalRegions = input.countryContext.totalRegions
            alertRegions = input.countryContext.alertRegions
            clearCount = input.countryContext.clearCount
            unavailableCount = input.countryContext.unavailableCount
            sourceRaw = input.countryContext.sourceRaw
            isSnapshotStale = input.countryContext.isSnapshotStale
            localeIdentifier = input.localeIdentifier
        }
    }

    private static let enhancementTimeout: Duration = .seconds(3)

    private let summarizer: any StatusDetailsSummarizing
    private let baselineSummarizer = DeterministicStatusDetailsProvider()
    private let source: any ExplanationStatusContext
    private let aggregator = CountrySituationAggregator()
    private let now: () -> Date
    private let refreshInterval: () -> TimeInterval
    private let locale: () -> Locale

    private(set) var isLoading = false
    private(set) var isFailure = false
    private var deliveredResult: (key: SemanticKey, rows: [String])?
    private var observedKey: SemanticKey?
    private var activeRequestKey: SemanticKey?
    private var requestTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(
        summarizer: any StatusDetailsSummarizing,
        source: any ExplanationStatusContext,
        now: @escaping () -> Date = { Date() },
        refreshInterval: @escaping () -> TimeInterval,
        locale: @escaping () -> Locale = { .current }
    ) {
        self.summarizer = summarizer
        self.source = source
        self.now = now
        self.refreshInterval = refreshInterval
        self.locale = locale
        observedKey = Self.makeInput(
            source: source,
            aggregator: aggregator,
            now: now,
            refreshInterval: refreshInterval,
            locale: locale
        ).map(SemanticKey.init)
    }

    var currentInput: StatusDetailsInput? {
        Self.makeInput(
            source: source,
            aggregator: aggregator,
            now: now,
            refreshInterval: refreshInterval,
            locale: locale
        )
    }

    private var currentKey: SemanticKey? {
        currentInput.map(SemanticKey.init)
    }

    var canRequestSummary: Bool {
        guard let input = currentInput else { return false }
        return input.region.status.phase == .quiet || input.region.status.phase == .alarm
    }

    var presentationState: PresentationState {
        if let deliveredResult, deliveredResult.key == currentKey {
            return .result(deliveredResult.rows)
        }
        if isLoading {
            return .loading
        }
        if isFailure {
            return .error
        }
        return .idle
    }

    func requestSummary() {
        synchronizeWithCurrentContext()
        guard !isLoading, canRequestSummary, let input = currentInput else { return }
        startRequest(for: input)
    }

    func activate() {
        synchronizeWithCurrentContext()
        guard presentationState == .idle else { return }
        requestSummary()
    }

    func retrySummary() {
        requestSummary()
    }

    func synchronizeWithCurrentContext() {
        let key = currentKey
        guard key != observedKey else { return }
        observedKey = key
        stopActiveRequest()
        deliveredResult = nil
        guard let input = currentInput,
              input.region.status.phase == .quiet || input.region.status.phase == .alarm else { return }
        startRequest(for: input)
    }

    func cancelActiveRequest() {
        stopActiveRequest()
    }

    func dismissSummary() {
        stopActiveRequest()
        deliveredResult = nil
    }

    private func stopActiveRequest() {
        requestGeneration += 1
        requestTask?.cancel()
        requestTask = nil
        activeRequestKey = nil
        isLoading = false
        isFailure = false
    }

    private func startRequest(for input: StatusDetailsInput) {
        let key = SemanticKey(input: input)
        isLoading = true
        isFailure = false
        requestGeneration += 1
        let generation = requestGeneration
        let summarizer = summarizer
        let baselineSummarizer = baselineSummarizer
        requestTask?.cancel()
        activeRequestKey = key
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let baseline = try await baselineSummarizer.summary(for: input)
                publishBaseline(generation: generation, key: key, text: baseline)
                let enhanced = try await BoundedAwait.value(timeout: Self.enhancementTimeout) {
                    try await summarizer.summary(for: input)
                }
                finishEnhancement(generation: generation, key: key, result: .success(enhanced))
            } catch is CancellationError {
                finishEnhancement(generation: generation, key: key, result: .failure(CancellationError()))
            } catch {
                finishEnhancement(generation: generation, key: key, result: .failure(error))
            }
        }
    }

    private func publishBaseline(generation: Int, key: SemanticKey, text: String) {
        guard generation == requestGeneration, activeRequestKey == key, key == currentKey else { return }
        deliveredResult = (key, Self.rows(from: text))
        isFailure = false
    }

    private func finishEnhancement(
        generation: Int,
        key: SemanticKey,
        result: Result<String, any Error>
    ) {
        guard generation == requestGeneration, activeRequestKey == key else { return }
        requestTask = nil
        activeRequestKey = nil
        defer { isLoading = false }
        guard key == currentKey else { return }
        switch result {
        case let .success(text):
            deliveredResult = (key, Self.rows(from: text))
            isFailure = false
        case .failure:
            isFailure = deliveredResult?.key != key
        }
    }

    private static func rows(from text: String) -> [String] {
        text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func makeInput(
        source: any ExplanationStatusContext,
        aggregator: CountrySituationAggregator,
        now: @escaping () -> Date,
        refreshInterval: () -> TimeInterval,
        locale: () -> Locale
    ) -> StatusDetailsInput? {
        guard let snapshot = source.lastSnapshot,
              let aggregate = aggregator.aggregate(snapshot: snapshot) else { return nil }
        let regionInput = StatusExplanationInput(
            snapshot: snapshot,
            region: source.currentRegion,
            status: source.state
        )
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: now(),
            refreshIntervalSeconds: refreshInterval()
        )
        return StatusDetailsInput(
            region: regionInput,
            countryAggregate: aggregate,
            countryContext: context,
            localeIdentifier: locale().identifier,
            refreshRevision: 0
        )
    }
}
