// swiftlint:disable force_unwrapping
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct StatusDetailsViewModelTests {
    private let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)

    private struct SUT {
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

    @Test
    func activationCreatesOneRequestContainingRegionCountryAndLocale() async throws {
        let sut = makeSUT(alarms: [.kharkiv], locale: Locale(identifier: "uk"))

        sut.viewModel.activate()
        await sut.spy.waitUntilPending()

        #expect(await sut.spy.requestCount() == 1)
        let input = try #require(await sut.spy.receivedInputs().first)
        #expect(input.region.region == .kyivCity)
        #expect(input.countryAggregate.alerts == [.kharkiv])
        #expect(input.localeIdentifier.hasPrefix("uk"))
        await sut.spy.resolve(.success("Регіон\nКраїна"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["Регіон", "Країна"]))
    }

    @Test
    func repeatedActivationRemainsSingleFlight() async {
        let sut = makeSUT()

        sut.viewModel.activate()
        sut.viewModel.activate()
        await sut.spy.waitUntilPending()

        #expect(await sut.spy.requestCount() == 1)
        await sut.spy.resolve(.success("Region\nCountry"))
        await drain()
    }

    @Test
    func regionChangeExpiresResultAndAutomaticallyStartsReplacement() async {
        let sut = makeSUT()
        sut.viewModel.activate()
        await sut.spy.waitUntilPending()
        await sut.spy.resolve(.success("Old region\nOld country"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["Old region", "Old country"]))

        sut.source.currentRegion = .kharkiv
        sut.viewModel.synchronizeWithCurrentContext()

        await sut.spy.waitUntilPending()
        #expect(sut.viewModel.presentationState == .loading)
        #expect(await sut.spy.requestCount() == 2)
    }

    @Test
    func refreshStartExpiresSummaryAndSuccessfulRefreshGeneratesReplacement() async {
        let sut = makeSUT()
        sut.viewModel.activate()
        await sut.spy.waitUntilPending()
        await sut.spy.resolve(.success("Region\nCountry\nFreshness"))
        await drain()
        #expect(sut.viewModel.presentationState == .result(["Region", "Country", "Freshness"]))

        sut.source.statusDetailsRevision = nil
        sut.viewModel.synchronizeWithCurrentContext()
        #expect(sut.viewModel.presentationState == .idle)

        sut.source.lastSnapshot = makeSnapshot(alarms: [.kharkiv])
        sut.source.statusDetailsRevision = 1
        sut.viewModel.synchronizeWithCurrentContext()
        await sut.spy.waitUntilPending()

        #expect(sut.viewModel.presentationState == .loading)
        #expect(await sut.spy.requestCount() == 2)
    }

    @Test
    func elapsedTimeDoesNotExpireSummaryWithoutRefresh() async {
        var currentTime = checkedAt.addingTimeInterval(10)
        let sut = makeSUT(now: { currentTime })
        sut.viewModel.activate()
        await sut.spy.waitUntilPending()
        await sut.spy.resolve(.success("Region\nCountry\nFreshness"))
        await drain()

        currentTime = checkedAt.addingTimeInterval(50)

        #expect(sut.viewModel.presentationState == .result(["Region", "Country", "Freshness"]))
    }

    @Test(arguments: ["en", "ru", "uk"])
    func promptRequestsSupportedLanguage(_ language: String) {
        let input = makeInput(localeIdentifier: language, rawSource: "Vadym Klymenko API (default)")
        let prompt = FoundationModelsStatusDetailsProvider.promptFacts(for: input)

        #expect(prompt.contains("requested_language: \(language)"))
        #expect(prompt.contains("selected_region_title:"))
        #expect(prompt.contains("situation_state:"))
        #expect(prompt.contains("source: public_alert_feed"))
        #expect(!prompt.contains("data_age_seconds"))
        #expect(!prompt.contains("data_stale"))
        #expect(!prompt.contains("Vadym"))
    }

    @Test
    func modelCannotOverrideDeterministicSelectedRegionStatus() throws {
        let input = makeInput(
            localeIdentifier: "en",
            rawSource: "feed",
            alarms: [.kharkiv]
        )
        let result = try FoundationModelsStatusDetailsProvider.assembled(
            StatusDetailsDraft(countrySummary: "Alerts are active in 1 other region: Kharkiv."),
            input: input,
            limits: ExplanationRunLimits(
                maxModelTurns: 1,
                maxToolCalls: 0,
                maxFinalCharacters: 700,
                timeout: .seconds(5)
            )
        )

        #expect(result.split(separator: "\n").map(String.init) == [
            "Latest data shows no active alert in the selected region.",
            "Alerts are active in 1 other region: Kharkiv."
        ])
        #expect(!result.contains("Alerts are active in Kyiv"))
    }

    @Test
    func freshDeterministicFallbackUsesRussianWithoutFreshnessLine() async throws {
        let input = makeInput(localeIdentifier: "ru", rawSource: "feed")

        let result = try await DeterministicStatusDetailsProvider().summary(for: input)

        #expect(result.contains("По последним данным, в выбранном регионе тревоги нет."))
        #expect(result.contains("Сейчас ни в одном из 25 регионов Украины нет тревоги."))
        #expect(!result.contains("Country:"))
        #expect(!result.contains("актуаль"))
        #expect(result.split(separator: "\n").count == 2)
    }

    @Test
    func activeCountryFallbackUsesNaturalRussianSentenceWithoutGeneratedNames() async throws {
        let input = makeInput(
            localeIdentifier: "ru",
            rawSource: "feed",
            alarms: [.kharkiv, .sumy]
        )

        let result = try await DeterministicStatusDetailsProvider().summary(for: input)

        #expect(result.contains("Сейчас тревога объявлена в 2 из 25 регионов Украины."))
        #expect(!result.contains("Затронуты:"))
        #expect(result.split(separator: "\n").count == 2)
    }

    @Test
    func staleDeterministicFallbackAddsLocalizedWarning() async throws {
        let input = makeInput(localeIdentifier: "uk", rawSource: "feed", age: 121)

        let result = try await DeterministicStatusDetailsProvider().summary(for: input)

        #expect(result.contains("За останніми даними, у вибраному регіоні тривоги немає."))
        #expect(result.contains("Дані можуть бути застарілими"))
        #expect(result.split(separator: "\n").count == 3)
    }

    private func makeSUT(
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

    private func makeInput(
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

    private func makeSnapshot(
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

    private func drain() async {
        await Task.yield()
        await Task.yield()
    }
}

struct CountrySummaryLocalizationTests {
    @Test
    func fallbackUsesRequestedRussianLocalization() throws {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = AlertsSnapshot(
            source: "test",
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: Dictionary(uniqueKeysWithValues: AlertRegion.allCases.map { ($0, .quiet) })
        )
        let aggregator = CountrySituationAggregator()
        let aggregate = try #require(aggregator.aggregate(snapshot: snapshot))
        let context = aggregator.context(
            from: aggregate,
            snapshot: snapshot,
            now: checkedAt.addingTimeInterval(60),
            refreshIntervalSeconds: 60
        )

        let text = aggregator.fallbackSummary(
            from: aggregate,
            context: context,
            locale: Locale(identifier: "ru")
        )

        #expect(text.contains("Во всех 25 регионах тревог нет"))
        #expect(text.contains("Данные актуальны"))
        #expect(!text.contains("All 25 regions report clear"))
    }
}
