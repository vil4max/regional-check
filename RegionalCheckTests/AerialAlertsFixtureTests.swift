import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The fixture pins the live feed's 26 keys: the 25 app regions plus Sevastopol, which the app
/// ignores because it is not an app region (REQ-REGION-001). Production decoding goes through
/// `UbillingProvider`; only the raw key set is read here, so the feed's shape is not restated.
struct AerialAlertsFixtureTests {
    private static let sevastopolKey = "Севастополь"
    private static let crimeaKey = "Автономна Республіка Крим"

    @Test("REQ-REGION-001 the pinned feed is the catalog's keys plus Sevastopol")
    func fixtureKeys_areCatalogPlusSevastopol() throws {
        let object = try JSONSerialization.jsonObject(with: TestFixtures.aerialAlertsFixtureData())
        let states = try #require((object as? [String: Any])?["states"] as? [String: Any])
        let catalogKeys = Set(AlertRegion.allCases.map(\.apiKey))

        #expect(states.count == 26)
        #expect(Set(states.keys) == catalogKeys.union([Self.sevastopolKey]))
    }

    @Test("REQ-REGION-001 the provider maps every catalog region and ignores Sevastopol and Crimea")
    func providerOutput_coversCatalogWithoutSevastopolOrCrimea() async throws {
        let response = try #require(
            HTTPURLResponse(
                url: UbillingProvider.endpoint,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            ))
        let provider = UbillingProvider(
            httpClient: MockHTTPClient(data: try TestFixtures.aerialAlertsFixtureData(), response: response)
        )

        let snapshot = try await provider.fetchAlerts()

        #expect(Set(snapshot.statuses.keys) == Set(AlertRegion.allCases))
        #expect(AlertRegion.from(apiKey: Self.sevastopolKey) == nil)
        #expect(AlertRegion.from(apiKey: Self.crimeaKey) == nil)
    }
}
