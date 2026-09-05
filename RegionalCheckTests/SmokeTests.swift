import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct SmokeTests {
    @Test
    func allStates_showExpectedTitlesAndSymbols() {
        TestLocale.english {
            let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
            let idle = StatusState.idle
            let quiet = StatusState.quiet(lastCheckedAt: checkedAt)
            let alarm = StatusState.alarm(lastCheckedAt: checkedAt)
            let error = StatusState.error
            let regionUnavailable = StatusState.regionUnavailable

            #expect(idle.title == "Checking…")
            #expect(quiet.title == "No Alert")
            #expect(alarm.title == "Alert")
            #expect(error.title == "Unavailable")
            #expect(regionUnavailable.title == "Region Unavailable")

            #expect(idle.phase == .idle)
            #expect(quiet.phase == .quiet)
            #expect(alarm.phase == .alarm)
            #expect(error.phase == .error)
            #expect(regionUnavailable.phase == .regionUnavailable)

            #expect(idle.symbolName == "arrow.triangle.2.circlepath")
            #expect(quiet.symbolName == "checkmark.circle.fill")
            #expect(alarm.symbolName == "exclamationmark.circle.fill")
            #expect(error.symbolName == "questionmark.circle.fill")

            #expect(idle.explanation == String(localized: "status.explanation.updating"))
            #expect(quiet.explanation == String(localized: "status.explanation.quiet"))
            #expect(alarm.explanation == String(localized: "status.explanation.loud"))
            #expect(error.explanation == String(localized: "status.explanation.unknown"))

            #expect(idle.detailText == nil)
            #expect(error.detailText == "Tap Refresh to try again")
            #expect(quiet.detailText?.hasPrefix("Updated:") == true)
            #expect(alarm.detailText?.hasPrefix("Updated:") == true)
            #expect(quiet.checkedAt == checkedAt)
            #expect(alarm.checkedAt == checkedAt)
            #expect(idle.checkedAt == nil)
            #expect(error.checkedAt == nil)
        }
    }

    @Test
    func onboardingPurpose_usesExpectedCTAKeys() {
        TestLocale.english {
            #expect(OnboardingPurpose.firstLaunch.ctaTitleKey == "Get Started")
            #expect(OnboardingPurpose.about.ctaTitleKey == "Got It")
        }
    }

    @Test
    @MainActor
    func controller_appliesScreenshotFixtures() {
        TestLocale.english {
            let provider = MockStatusProvider(snapshot: TestFixtures.quietSnapshot())
            let controller = StatusController(region: .kyivCity, provider: provider)

            controller.applyScreenshotFixture("allClear")
            #expect(controller.state.title == "No Alert")
            #expect(controller.regionTitle == String(localized: "Kyiv"))

            controller.applyScreenshotFixture("alertActive")
            #expect(controller.state.title == "Alert")

            controller.applyScreenshotFixture("checking")
            #expect(controller.state == .idle)

            controller.applyScreenshotFixture("unavailable")
            #expect(controller.state == .error)
        }
    }

    @Test
    @MainActor
    func controller_startsIdle_thenShowsQuiet() async {
        await TestLocale.english {
            let checkedAt = Date(timeIntervalSince1970: 1)
            let provider = MockStatusProvider(snapshot: TestFixtures.quietSnapshot(checkedAt: checkedAt))
            let controller = StatusController(region: .kyivCity, provider: provider)

            #expect(controller.state == .idle)
            #expect(controller.regionTitle == String(localized: "Kyiv"))
            #expect(controller.state.explanation == String(localized: "status.explanation.updating"))

            await controller.refresh()

            guard case let .quiet(lastCheckedAt) = controller.state else {
                Issue.record("Expected quiet state, got \(controller.state)")
                return
            }
            #expect(lastCheckedAt == checkedAt)
            #expect(controller.state.title == "No Alert")
            #expect(controller.state.explanation == String(localized: "status.explanation.quiet"))
            #expect(controller.state.detailText?.hasPrefix("Updated:") == true)
        }
    }

    @Test
    @MainActor
    func controller_showsAlarmFromProvider() async {
        await TestLocale.english {
            let checkedAt = Date(timeIntervalSince1970: 1)
            let provider = MockStatusProvider(
                snapshot: AlertsSnapshot(
                    source: "test",
                    serverCachedAt: checkedAt,
                    fetchedAt: checkedAt,
                    statuses: [.kyivCity: .alarm]
                )
            )
            let controller = StatusController(region: .kyivCity, provider: provider)

            await controller.refresh()

            guard case let .alarm(lastCheckedAt) = controller.state else {
                Issue.record("Expected alarm state, got \(controller.state)")
                return
            }
            #expect(lastCheckedAt == checkedAt)
            #expect(controller.state.title == "Alert")
            #expect(controller.state.explanation == String(localized: "status.explanation.loud"))
        }
    }

    @Test
    @MainActor
    func controller_showsUnknownOnFailure() async {
        await TestLocale.english {
            struct TestError: Error {}
            let provider = MockStatusProvider(error: TestError())
            let controller = StatusController(region: .kyivCity, provider: provider)

            await controller.refresh()

            #expect(controller.state == .error)
            #expect(controller.state.title == "Unavailable")
            #expect(controller.state.detailText == "Tap Refresh to try again")
        }
    }

    @Test
    @MainActor
    func refreshPolicy_baselineIsOneMinute() {
        let env = RefreshEnvironment(
            isAlarmActive: false,
            isLowPowerModeEnabled: false,
            thermalState: .nominal,
            isExpensiveNetwork: false,
            isConstrainedNetwork: false
        )
        #expect(RefreshPolicy.baseIntervalSeconds(for: env) == 60)
    }

    @Test
    @MainActor
    func controller_updatesRegionTitle() {
        TestLocale.english {
            let provider = MockStatusProvider(
                snapshot: AlertsSnapshot(
                    source: "test",
                    serverCachedAt: Date(),
                    fetchedAt: Date(),
                    statuses: [.kyivCity: .quiet, .kyivOblast: .quiet]
                )
            )
            let controller = StatusController(region: .kyivCity, provider: provider)
            controller.setRegion(.kyivOblast)
            #expect(controller.regionTitle == String(localized: "Київська область"))
        }
    }
}

extension SmokeTests {
    @Test(arguments: [
        (true, AlertStatus.alarm),
        (false, AlertStatus.quiet)
    ])
    func provider_parsesKyivStatus(alertnow: Bool, expected: AlertStatus) async throws {
        let provider = try TestFixtures.makeProvider(
            json: TestFixtures.kyivJSON(alertnow: alertnow),
            now: Date(timeIntervalSince1970: 123)
        )
        let snapshot = try await provider.fetchAlerts()
        #expect(snapshot.status(for: .kyivCity) == expected)
        if alertnow {
            #expect(snapshot.source == "test")
            #expect(snapshot.fetchedAt == Date(timeIntervalSince1970: 123))
            #expect(snapshot.checkedAt == ISO8601DateFormatter().date(from: "2025-12-31T22:00:00Z"))
        }
    }

    @Test
    func provider_parsesCachedAtInKyivSummerTime() async throws {
        let json = """
        {
          "source": "test",
          "cachedat": "2026-08-14 12:00:00",
          "states": {
            "м. Київ": { "alertnow": false, "changed": "2026-08-14 12:00:00" }
          }
        }
        """
        let provider = try TestFixtures.makeProvider(json: json)
        let snapshot = try await provider.fetchAlerts()
        #expect(snapshot.checkedAt == ISO8601DateFormatter().date(from: "2026-08-14T09:00:00Z"))
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
        let provider = try TestFixtures.makeProvider(json: json)
        let snapshot = try await provider.fetchAlerts()
        #expect(snapshot.status(for: .lviv) == .alarm)
    }

    @Test
    func provider_omitsMissingRegionFromSnapshot() async throws {
        let provider = try TestFixtures.makeProvider(json: TestFixtures.kyivJSON(alertnow: true))
        let snapshot = try await provider.fetchAlerts()
        #expect(snapshot.status(for: .odesa) == nil)
        #expect(snapshot.status(for: .kyivCity) == .alarm)
    }

    @Test
    func provider_throwsOnHTTPError() async throws {
        let url = try #require(URL(string: "https://ubilling.net.ua/aerialalerts/"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        ))
        let http = MockHTTPClient(data: Data("{}".utf8), response: response)
        let provider = UbillingProvider(httpClient: http)

        do {
            _ = try await provider.fetchAlerts()
            Issue.record("Expected HTTP error")
        } catch let error as UbillingError {
            guard case let .unexpectedResponse(statusCode, _, _) = error else {
                Issue.record("Expected unexpectedResponse, got \(error)")
                return
            }
            #expect(statusCode == 500)
        } catch {
            Issue.record("Expected UbillingError, got \(error)")
        }
    }

    @Test
    func provider_throwsOnNonJSONResponse() async throws {
        let url = try #require(URL(string: "https://ubilling.net.ua/aerialalerts/"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "text/html"]
        ))
        let http = MockHTTPClient(data: Data("<html></html>".utf8), response: response)
        let provider = UbillingProvider(httpClient: http)

        do {
            _ = try await provider.fetchAlerts()
            Issue.record("Expected non-JSON error")
        } catch let error as UbillingError {
            guard case .unexpectedResponse = error else {
                Issue.record("Expected unexpectedResponse, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected UbillingError, got \(error)")
        }
    }

    @Test
    func provider_throwsOnBrokenJSON() async throws {
        let url = try #require(URL(string: "https://ubilling.net.ua/aerialalerts/"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
        let http = MockHTTPClient(data: Data("{not json".utf8), response: response)
        let provider = UbillingProvider(httpClient: http)

        do {
            _ = try await provider.fetchAlerts()
            Issue.record("Expected decode error")
        } catch let error as UbillingError {
            guard case .unexpectedResponse = error else {
                Issue.record("Expected unexpectedResponse, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected UbillingError, got \(error)")
        }
    }

    @Test
    func provider_throwsWhenOffline() async throws {
        let url = try #require(URL(string: "https://ubilling.net.ua/aerialalerts/"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))
        let http = MockHTTPClient(
            data: Data(),
            response: response,
            error: URLError(.notConnectedToInternet)
        )
        let provider = UbillingProvider(httpClient: http)

        do {
            _ = try await provider.fetchAlerts()
            Issue.record("Expected offline error")
        } catch let error as URLError {
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record("Expected URLError, got \(error)")
        }
    }

    @Test
    func regionStore_savesAndLoadsRegions() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
            store.save(.kyivCity)
            #expect(store.load() == .kyivCity)
            store.save(.kharkiv)
            #expect(store.load() == .kharkiv)
        }
    }
}
