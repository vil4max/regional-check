import DriveCheckKit
import Foundation
import Observation

/// Owns the async country-overview presentation state.
/// Mirrors the proven explanation lifecycle: immutable input per run,
/// generation token, single-flight taps, obsolete results never displayed.
@MainActor
@Observable
final class CountrySummaryViewModel {
    enum PresentationState: Equatable {
        case idle
        case loading
        case result([String])
        case error
    }

    /// Immutable facts captured at request time; a changed snapshot invalidates runs.
    struct Input: Equatable, Sendable {
        let aggregate: CountrySituationAggregate
        let context: CountrySituationContext
        let snapshotCheckedAt: Date

        static func == (lhs: Input, rhs: Input) -> Bool {
            lhs.aggregate == rhs.aggregate
                && lhs.snapshotCheckedAt == rhs.snapshotCheckedAt
                && lhs.context.state == rhs.context.state
                && lhs.context.totalRegions == rhs.context.totalRegions
                && lhs.context.alertRegions == rhs.context.alertRegions
                && lhs.context.clearCount == rhs.context.clearCount
                && lhs.context.unavailableCount == rhs.context.unavailableCount
                && lhs.context.sourceRaw == rhs.context.sourceRaw
                && lhs.context.isSnapshotStale == rhs.context.isSnapshotStale
        }
    }

    private let summarizer: any CountrySummarizing
    private let source: any ExplanationStatusContext
    private let aggregator = CountrySituationAggregator()
    private let now: () -> Date
    private let refreshInterval: () -> TimeInterval

    private(set) var isLoading = false
    private(set) var isFailure = false
    private var deliveredResult: (input: Input, rows: [String])?
    private var observedInput: Input?
    private var activeRequestInput: Input?
    private var requestTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(
        summarizer: any CountrySummarizing,
        source: any ExplanationStatusContext,
        now: @escaping () -> Date = { Date() },
        refreshInterval: @escaping () -> TimeInterval
    ) {
        self.summarizer = summarizer
        self.source = source
        self.now = now
        self.refreshInterval = refreshInterval
        observedInput = Self.makeInput(
            source: source,
            aggregator: aggregator,
            now: now,
            refreshInterval: refreshInterval
        )
    }

    var currentInput: Input? {
        Self.makeInput(
            source: source,
            aggregator: aggregator,
            now: now,
            refreshInterval: refreshInterval
        )
    }

    /// Available whenever a snapshot exists — including the all-data-missing one.
    var canRequestSummary: Bool {
        currentInput != nil
    }

    var presentationState: PresentationState {
        if isLoading {
            return .loading
        }
        if isFailure {
            return .error
        }
        if let deliveredResult, deliveredResult.input == currentInput {
            return .result(deliveredResult.rows)
        }
        return .idle
    }

    func requestSummary() {
        synchronizeWithCurrentContext()
        guard !isLoading, canRequestSummary, let input = currentInput else { return }
        startRequest(for: input)
    }

    func retrySummary() {
        requestSummary()
    }

    func synchronizeWithCurrentContext() {
        let input = currentInput
        guard input != observedInput else { return }
        observedInput = input
        stopActiveRequest()
        deliveredResult = nil
    }

    /// Screen exit cancels an in-flight run; a delivered result stays valid
    /// for its unchanged input and is simply not re-fetched.
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
        activeRequestInput = nil
        isLoading = false
        isFailure = false
    }

    private func startRequest(for input: Input) {
        isLoading = true
        isFailure = false
        requestGeneration += 1
        let generation = requestGeneration
        requestTask?.cancel()
        activeRequestInput = input
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await summarizer.summary(
                    for: input.aggregate,
                    context: input.context
                )
                complete(generation: generation, input: input, result: .success(text))
            } catch is CancellationError {
                complete(generation: generation, input: input, result: .failure(CancellationError()))
            } catch {
                complete(generation: generation, input: input, result: .failure(error))
            }
        }
    }

    private func complete(
        generation: Int,
        input: Input,
        result: Result<String, any Error>
    ) {
        guard generation == requestGeneration, activeRequestInput == input else { return }
        requestTask = nil
        activeRequestInput = nil
        defer { isLoading = false }
        // A late response for obsolete facts must never be displayed.
        guard input == currentInput else { return }
        switch result {
        case let .success(text):
            let rows = text
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            deliveredResult = (input, rows)
            isFailure = false
        case .failure:
            isFailure = true
        }
    }

    private static func makeInput(
        source: any ExplanationStatusContext,
        aggregator: CountrySituationAggregator,
        now: @escaping () -> Date,
        refreshInterval: () -> TimeInterval
    ) -> Input? {
        guard let snapshot = source.lastSnapshot,
              let aggregate = aggregator.aggregate(snapshot: snapshot) else { return nil }
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: now(),
            refreshIntervalSeconds: refreshInterval()
        )
        return Input(
            aggregate: aggregate,
            context: context,
            snapshotCheckedAt: snapshot.checkedAt
        )
    }
}

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
        let alertRegions: [AlertRegion]
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