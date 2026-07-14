import Foundation
import Testing
@testable import RegionalCheck

struct SmokeTests {
    @Test
    func allStates_showExpectedTitlesAndSymbols() {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let idle = StatusState.idle
        let quiet = StatusState.quiet(lastCheckedAt: checkedAt, source: "test")
        let alarm = StatusState.alarm(lastCheckedAt: checkedAt, source: "test")
        let error = StatusState.error(message: "Unknown")

        #expect(idle.title == "Checking…")
        #expect(quiet.title == "Quiet")
        #expect(alarm.title == "Loud")
        #expect(error.title == "Unknown")

        #expect(idle.symbolName == "hourglass")
        #expect(quiet.symbolName == "speaker.slash.fill")
        #expect(alarm.symbolName == "speaker.wave.3.fill")
        #expect(error.symbolName == "questionmark.circle.fill")

        #expect(idle.detailText == nil)
        #expect(error.detailText == "Tap Refresh to try again")
        #expect(quiet.detailText?.hasPrefix("Updated:") == true)
        #expect(alarm.detailText?.hasPrefix("Updated:") == true)
    }

    @Test
    func regionTitles_matchBusinessRules() {
        #expect(AlertRegion.kyivCity.title == "Kyiv")
        #expect(AlertRegion(kind: .oblast(name: "Львівська область")).title == "Львівська область")
    }

    @Test
    @MainActor
    func controller_startsIdle_thenShowsQuiet() async {
        let provider = MockStatusProvider { region in
            AlertStatusSnapshot(
                region: region,
                status: .quiet,
                checkedAt: Date(timeIntervalSince1970: 1),
                source: "test"
            )
        }
        let controller = StatusController(
            region: .kyivCity,
            provider: provider,
            now: { Date(timeIntervalSince1970: 100) }
        )

        #expect(controller.state == .idle)
        #expect(controller.regionTitle == "Kyiv")

        controller.refresh()
        await waitUntilReady(controller: controller)

        guard case .quiet(let lastCheckedAt, let source) = controller.state else {
            Issue.record("Expected Quiet/quiet state, got \(controller.state)")
            return
        }
        #expect(source == "test")
        #expect(lastCheckedAt == Date(timeIntervalSince1970: 100))
        #expect(controller.state.title == "Quiet")
    }

    @Test
    @MainActor
    func controller_showsAlarmFromProvider() async {
        let provider = MockStatusProvider { region in
            AlertStatusSnapshot(
                region: region,
                status: .alarm,
                checkedAt: Date(timeIntervalSince1970: 1),
                source: "test"
            )
        }
        let controller = StatusController(
            region: .kyivCity,
            provider: provider,
            now: { Date(timeIntervalSince1970: 100) }
        )

        controller.refresh()
        await waitUntilReady(controller: controller)

        guard case .alarm(let lastCheckedAt, let source) = controller.state else {
            Issue.record("Expected Loud/alarm state, got \(controller.state)")
            return
        }
        #expect(source == "test")
        #expect(lastCheckedAt == Date(timeIntervalSince1970: 100))
        #expect(controller.state.title == "Loud")
    }

    @Test
    @MainActor
    func controller_showsUnableToUpdateOnFailure() async {
        struct TestError: Error {}
        let provider = MockStatusProvider { _ in throw TestError() }
        let controller = StatusController(region: .kyivCity, provider: provider)

        controller.refresh()
        await waitUntilReady(controller: controller)

        guard case .error(let message) = controller.state else {
            Issue.record("Expected Unknown state, got \(controller.state)")
            return
        }
        #expect(message == "Unknown")
        #expect(controller.state.title == "Unknown")
    }

    @Test
    @MainActor
    func controller_updatesRegionTitle() {
        let provider = MockStatusProvider { region in
            AlertStatusSnapshot(region: region, status: .quiet, checkedAt: Date(), source: "test")
        }
        let controller = StatusController(region: .kyivCity, provider: provider)
        let oblast = AlertRegion(kind: .oblast(name: "Київська область"))

        controller.setRegion(oblast)
        #expect(controller.regionTitle == "Київська область")
    }

    @Test
    func provider_parsesKyivAlarmFromJSON() async throws {
        let provider = try makeProvider(json: kyivJSON(alertnow: true), now: Date(timeIntervalSince1970: 123))
        let snapshot = try await provider.fetchStatus(region: .kyivCity)
        #expect(snapshot.status == .alarm)
        #expect(snapshot.source == "test")
        #expect(snapshot.checkedAt == Date(timeIntervalSince1970: 123))
    }

    @Test
    func provider_parsesKyivQuietFromJSON() async throws {
        let provider = try makeProvider(json: kyivJSON(alertnow: false))
        let snapshot = try await provider.fetchStatus(region: .kyivCity)
        #expect(snapshot.status == .quiet)
    }

    @Test
    func provider_parsesOblastAlarmFromJSON() async throws {
        let json = """
        {
          "source": "test",
          "cachedat": "2026-01-01 00:00:00",
          "states": {
            "Львівська область": { "alertnow": true, "changed": "2026-01-01 00:00:00" }
          }
        }
        """
        let provider = try makeProvider(json: json)
        let region = AlertRegion(kind: .oblast(name: "Львівська область"))
        let snapshot = try await provider.fetchStatus(region: region)
        #expect(snapshot.status == .alarm)
        #expect(snapshot.region == region)
    }

    @Test
    func provider_throwsWhenRegionMissing() async {
        let provider = try! makeProvider(json: kyivJSON(alertnow: true))
        let region = AlertRegion(kind: .oblast(name: "Одеська область"))
        await #expect(throws: UbillingError.missingRegionKey("Одеська область")) {
            _ = try await provider.fetchStatus(region: region)
        }
    }

    @Test
    func provider_throwsOnHTTPError() async {
        let response = HTTPURLResponse(
            url: URL(string: "https://ubilling.net.ua/aerialalerts/")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!
        let http = MockHTTPClient(result: .success(Data("{}".utf8), response))
        let provider = UbillingProvider(httpClient: http)

        do {
            _ = try await provider.fetchStatus(region: .kyivCity)
            Issue.record("Expected HTTP error")
        } catch let error as UbillingError {
            guard case .unexpectedResponse(let statusCode, _, _) = error else {
                Issue.record("Expected unexpectedResponse, got \(error)")
                return
            }
            #expect(statusCode == 500)
        } catch {
            Issue.record("Expected UbillingError, got \(error)")
        }
    }

    @Test
    func regionStore_savesAndLoadsRegions() {
        let suite = "SmokeTests.RegionStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(userDefaults: defaults)

        store.save(.kyivCity)
        #expect(store.load() == .kyivCity)

        let oblast = AlertRegion(kind: .oblast(name: "Харківська область"))
        store.save(oblast)
        #expect(store.load() == oblast)
    }

    @Test
    func regionStore_migratesLegacyKind() {
        let suite = "SmokeTests.RegionStore.legacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("kyivCity", forKey: "selected_region_kind")

        let store = RegionStore(userDefaults: defaults)
        #expect(store.load() == .kyivCity)
        #expect(defaults.string(forKey: "selected_region_kind") == nil)
    }
}

private func kyivJSON(alertnow: Bool) -> String {
    """
    {
      "source": "test",
      "cachedat": "2026-01-01 00:00:00",
      "states": {
        "м. Київ": { "alertnow": \(alertnow), "changed": "2026-01-01 00:00:00" }
      }
    }
    """
}

private func makeProvider(json: String, now: Date = Date()) throws -> UbillingProvider {
    let data = Data(json.utf8)
    let response = HTTPURLResponse(
        url: URL(string: "https://ubilling.net.ua/aerialalerts/")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let http = MockHTTPClient(result: .success(data, response))
    return UbillingProvider(httpClient: http, now: { now })
}

private struct MockStatusProvider: StatusProviding {
    let statusForRegion: @Sendable (AlertRegion) async throws -> AlertStatusSnapshot

    init(statusForRegion: @escaping @Sendable (AlertRegion) async throws -> AlertStatusSnapshot) {
        self.statusForRegion = statusForRegion
    }

    func fetchStatus(region: AlertRegion) async throws -> AlertStatusSnapshot {
        try await statusForRegion(region)
    }
}

private struct MockHTTPClient: HTTPClient {
    enum Result: Sendable {
        case success(Data, URLResponse)
    }

    let result: Result

    func data(from url: URL) async throws -> (Data, URLResponse) {
        switch result {
        case .success(let data, let response):
            return (data, response)
        }
    }
}

@MainActor
private func waitUntilReady(controller: StatusController) async {
    for _ in 0..<50 {
        if case .idle = controller.state {
            await Task.yield()
            continue
        }
        return
    }
    Issue.record("Timed out waiting for controller state update")
}
