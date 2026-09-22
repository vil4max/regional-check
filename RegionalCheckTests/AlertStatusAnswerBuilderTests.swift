import DriveCheckKit
import Foundation
import Testing

struct AlertStatusAnswerBuilderTests {
    private static let now = Date(timeIntervalSince1970: 1_720_000_000)
    private static let english = Locale(identifier: "en_US")

    private static func snapshot(age: TimeInterval, statuses: [AlertRegion: AlertStatus]) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "Mørk Skog",
            serverCachedAt: now.addingTimeInterval(-age),
            fetchedAt: now.addingTimeInterval(-age),
            statuses: statuses
        )
    }

    private static func answer(_ snapshot: AlertsSnapshot?, region: AlertRegion = .kyivCity) -> AlertStatusAnswerBuilder
        .Answer
    {
        TestLocale.english {
            AlertStatusAnswerBuilder.answer(for: region, snapshot: snapshot, now: now, locale: english)
        }
    }

    @Test("REQ-SURF-011 a fresh answer names the region and one status, with no age")
    func freshAnswerHasNoAge() {
        let answer = Self.answer(Self.snapshot(age: 30, statuses: [.kyivCity: .quiet]))
        #expect(answer.full == "Kyiv: No Alert.")
        #expect(answer.supporting == "Kyiv — No Alert")
    }

    @Test("REQ-SURF-011 the answer never names the data provider, fresh or stale")
    func answerNeverNamesProvider() {
        for age: TimeInterval in [30, 3600] {
            let answer = Self.answer(Self.snapshot(age: age, statuses: [.kyivCity: .alarm]))
            #expect(!answer.full.contains("Mørk Skog"))
            #expect(!answer.supporting.contains("Mørk Skog"))
        }
    }

    @Test("REQ-SURF-011 a stale answer says how old the data is")
    func staleAnswerSaysAge() {
        let answer = Self.answer(Self.snapshot(age: 12 * 60, statuses: [.kyivCity: .quiet]))
        #expect(answer.full == "Kyiv: No Alert. Updated 12 minutes ago.")
        #expect(answer.supporting == "Kyiv — No Alert\nUpdated 12 minutes ago")
    }

    @Test("REQ-SURF-011 the stale threshold is twice the base interval: 60 s in alarm, 120 s when quiet")
    func staleThresholdFollowsPhase() {
        #expect(Self.answer(Self.snapshot(age: 90, statuses: [.kyivCity: .alarm])).full.contains("Updated"))
        #expect(!Self.answer(Self.snapshot(age: 90, statuses: [.kyivCity: .quiet])).full.contains("Updated"))
        #expect(Self.answer(Self.snapshot(age: 150, statuses: [.kyivCity: .quiet])).full.contains("Updated"))
    }

    @Test("REQ-SURF-011 REQ-SURF-010 fresh quiet data surrounded by alerts answers Stay Alert")
    func surroundedFreshAnswersStayAlert() {
        let statuses: [AlertRegion: AlertStatus] = [
            .kyivCity: .quiet, .kyivOblast: .alarm, .chernihiv: .alarm, .zhytomyr: .alarm,
        ]
        #expect(Self.answer(Self.snapshot(age: 30, statuses: statuses)).full == "Kyiv: Stay Alert.")
        // Stale neighbours are as old as the region, so stale data never turns yellow.
        #expect(Self.answer(Self.snapshot(age: 600, statuses: statuses)).full.hasPrefix("Kyiv: No Alert."))
    }

    @Test("REQ-SURF-011 an alarm is never downgraded to Stay Alert")
    func alarmStaysAlert() {
        let statuses: [AlertRegion: AlertStatus] = [
            .kyivCity: .alarm, .kyivOblast: .alarm, .chernihiv: .alarm, .zhytomyr: .alarm,
        ]
        #expect(Self.answer(Self.snapshot(age: 10, statuses: statuses)).full == "Kyiv: Alert.")
    }

    @Test("REQ-SURF-011 with no snapshot at all the answer is No Current Data")
    func missingSnapshotAnswersNoCurrentData() {
        #expect(Self.answer(nil).full == "Kyiv: No Current Data.")
    }

    @Test("REQ-SURF-011 a region missing from the feed answers Region Unavailable")
    func missingRegionAnswersUnavailable() {
        #expect(Self.answer(Self.snapshot(age: 10, statuses: [:])).full == "Kyiv: Region Unavailable.")
    }

    @Test("REQ-SURF-011 REQ-PROVIDER-002 a Siri request fetches once and stores the fresh snapshot")
    func freshFetchIsStored() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveSnapshot(Self.snapshot(age: 600, statuses: [.kyivCity: .quiet]))
            let fresh = Self.snapshot(age: 2, statuses: [.kyivCity: .alarm])
            let provider = CountingProvider(result: .success(fresh))
            let result = await AlertStatusAnswerBuilder.currentSnapshot(store: store, provider: provider, now: Self.now)
            #expect(result == fresh)
            #expect(store.loadSnapshot() == fresh)
            #expect(await provider.requests.count == 1)
        }
    }

    @Test("REQ-SURF-011 a newer snapshot the app stored during the fetch is kept")
    func newerStoredSnapshotIsNotOverwritten() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveSnapshot(Self.snapshot(age: 600, statuses: [.kyivCity: .quiet]))
            // The app's refresh landed while the Siri request was in flight, a few seconds later.
            let older = Self.snapshot(age: 8, statuses: [.kyivCity: .quiet])
            let newer = Self.snapshot(age: 3, statuses: [.kyivCity: .alarm])
            let provider = CountingProvider(result: .success(older), onFetch: { store.saveSnapshot(newer) })
            let result = await AlertStatusAnswerBuilder.currentSnapshot(store: store, provider: provider, now: Self.now)
            #expect(result == newer)
            #expect(store.loadSnapshot() == newer)
        }
    }

    @Test("REQ-SURF-011 a failed fetch answers from the App Group cache")
    func failedFetchFallsBackToCache() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let cached = Self.snapshot(age: 600, statuses: [.kyivCity: .quiet])
            store.saveSnapshot(cached)
            let provider = CountingProvider(result: .failure(URLError(.notConnectedToInternet)))
            let result = await AlertStatusAnswerBuilder.currentSnapshot(store: store, provider: provider, now: Self.now)
            #expect(result == cached)
        }
    }

    @Test("REQ-SURF-011 a fetch that outlasts the budget answers from the cache and is cancelled")
    func slowFetchFallsBackToCacheWithinBudget() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let cached = Self.snapshot(age: 600, statuses: [.kyivCity: .quiet])
            store.saveSnapshot(cached)
            let provider = CountingProvider(result: .success(Self.snapshot(age: 1, statuses: [:])), delay: .seconds(60))
            let started = ContinuousClock.now
            let result = await AlertStatusAnswerBuilder.currentSnapshot(
                store: store,
                provider: provider,
                now: Self.now,
                budget: .milliseconds(100)
            )
            #expect(result == cached)
            #expect(store.loadSnapshot() == cached)
            #expect(ContinuousClock.now - started < .seconds(10))
        }
    }

    @Test("REQ-SURF-011 a snapshot dated in the future does not hold the fetch floor shut")
    func futureDatedSnapshotStillFetches() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveSnapshot(Self.snapshot(age: -3600, statuses: [.kyivCity: .quiet]))
            let fresh = Self.snapshot(age: 2, statuses: [.kyivCity: .alarm])
            let provider = CountingProvider(result: .success(fresh))
            let result = await AlertStatusAnswerBuilder.currentSnapshot(store: store, provider: provider, now: Self.now)
            #expect(result == fresh)
            #expect(await provider.requests.count == 1)
        }
    }

    @Test("REQ-SURF-011 REQ-PROVIDER-002 an HTTP 429 holds later Siri requests until its deadline")
    func rateLimitHoldsLaterRequests() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let cached = Self.snapshot(age: 600, statuses: [.kyivCity: .quiet])
            store.saveSnapshot(cached)
            let deadline = Self.now.addingTimeInterval(120)
            let limited = CountingProvider(result: .failure(UbillingError.rateLimited(retryAfter: deadline)))
            #expect(await AlertStatusAnswerBuilder
                .currentSnapshot(store: store, provider: limited, now: Self.now) == cached)
            #expect(store.loadRateLimitedUntil() == deadline)

            let fresh = Self.snapshot(age: 2, statuses: [.kyivCity: .alarm])
            let inside = CountingProvider(result: .success(fresh))
            let held = await AlertStatusAnswerBuilder.currentSnapshot(
                store: store,
                provider: inside,
                now: Self.now.addingTimeInterval(60)
            )
            #expect(held == cached)
            #expect(await inside.requests.isEmpty)

            let after = CountingProvider(result: .success(fresh))
            let resumed = await AlertStatusAnswerBuilder.currentSnapshot(
                store: store,
                provider: after,
                now: deadline.addingTimeInterval(1)
            )
            #expect(resumed == fresh)
            #expect(await after.requests.count == 1)
        }
    }

    @Test("REQ-SURF-011 a stored 429 deadline beyond the longest backoff does not hold Siri back")
    func farRateLimitDeadlineIsIgnored() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveSnapshot(Self.snapshot(age: 600, statuses: [.kyivCity: .quiet]))
            store.saveRateLimitedUntil(Self.now.addingTimeInterval(365 * 24 * 3600))
            let fresh = Self.snapshot(age: 2, statuses: [.kyivCity: .alarm])
            let provider = CountingProvider(result: .success(fresh))
            let result = await AlertStatusAnswerBuilder.currentSnapshot(store: store, provider: provider, now: Self.now)
            #expect(result == fresh)
            #expect(await provider.requests.count == 1)
        }
    }

    @Test("REQ-SURF-011 a cache dated slightly ahead by a clock change is not mistaken for an app write")
    func slightlyFutureCacheIsReplaced() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            store.saveSnapshot(Self.snapshot(age: -5, statuses: [.kyivCity: .quiet]))
            let fresh = Self.snapshot(age: 0, statuses: [.kyivCity: .alarm])
            let provider = CountingProvider(result: .success(fresh))
            let result = await AlertStatusAnswerBuilder.currentSnapshot(store: store, provider: provider, now: Self.now)
            #expect(result == fresh)
            #expect(store.loadSnapshot() == fresh)
        }
    }

    @Test("REQ-SURF-011 REQ-REFRESH-010 a snapshot fetched under 10 s ago is served without a request")
    func fetchFloorServesCache() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = SharedStore(userDefaults: defaults)
            let cached = Self.snapshot(age: 5, statuses: [.kyivCity: .quiet])
            store.saveSnapshot(cached)
            let provider = CountingProvider(result: .failure(URLError(.badServerResponse)))
            let result = await AlertStatusAnswerBuilder.currentSnapshot(store: store, provider: provider, now: Self.now)
            #expect(result == cached)
            #expect(await provider.requests.isEmpty)
        }
    }
}

/// Counts requests so a test can prove the Siri trigger costs exactly one (REQ-PROVIDER-002).
private actor CountingProvider: StatusProviding {
    private let result: Result<AlertsSnapshot, any Error>
    private let delay: Duration?
    /// Stands in for the app writing the App Group while this request is in flight.
    private let onFetch: @Sendable () -> Void
    private(set) var requests: [Date] = []

    init(
        result: Result<AlertsSnapshot, any Error>,
        delay: Duration? = nil,
        onFetch: @escaping @Sendable () -> Void = {}
    ) {
        self.result = result
        self.delay = delay
        self.onFetch = onFetch
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        requests.append(Date())
        onFetch()
        if let delay {
            try await Task.sleep(for: delay)
        }
        return try result.get()
    }
}
