import Foundation
import Testing
import RegionalCheckDomain
import RegionalCheckData

struct UbillingAirAlertProviderTests {
    @Test
    func fetchStatus_kyiv_alarm() async throws {
        let json = """
        {
          "source": "test",
          "cachedat": "2026-01-01 00:00:00",
          "states": {
            "м. Київ": { "alertnow": true, "changed": "2026-01-01 00:00:00" }
          }
        }
        """
        let data = Data(json.utf8)
        let response = HTTPURLResponse(url: URL(string: "https://ubilling.net.ua/aerialalerts/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let http = MockHTTPClient(result: .success(data, response))

        let provider = UbillingAirAlertProvider(httpClient: http, now: { Date(timeIntervalSince1970: 123) })
        let snapshot = try await provider.fetchStatus(region: .kyivCity)

        #expect(snapshot.region == .kyivCity)
        #expect(snapshot.status == .alarm)
        #expect(snapshot.source == "test")
        #expect(snapshot.checkedAt == Date(timeIntervalSince1970: 123))
    }

    @Test
    func fetchStatus_missingKyiv_throws() async {
        let json = """
        {
          "source": "test",
          "cachedat": "2026-01-01 00:00:00",
          "states": {}
        }
        """
        let data = Data(json.utf8)
        let response = HTTPURLResponse(url: URL(string: "https://ubilling.net.ua/aerialalerts/")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let http = MockHTTPClient(result: .success(data, response))

        let provider = UbillingAirAlertProvider(httpClient: http, now: { Date() })

        await #expect(throws: UbillingProviderError.missingRegionKey("м. Київ")) {
            _ = try await provider.fetchStatus(region: .kyivCity)
        }
    }
}

