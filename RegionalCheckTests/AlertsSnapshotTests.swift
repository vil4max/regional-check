import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct AlertsSnapshotTests {
    @Test
    func provider_decodesAllRegionsFromFixture() async throws {
        let data = try TestFixtures.aerialAlertsFixtureData()
        let url = try #require(URL(string: "https://ubilling.net.ua/aerialalerts/"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
        let provider = UbillingProvider(
            httpClient: MockHTTPClient(data: data, response: response),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let snapshot = try await provider.fetchAlerts()
        #expect(snapshot.statuses.count == 25)
        #expect(snapshot.status(for: .kyivCity) != nil)
        #expect(snapshot.status(for: .chernihiv) != nil)
        #expect(snapshot.source.isEmpty == false)
        #expect(snapshot.fetchedAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test
    @MainActor
    func controller_setRegion_appliesSnapshotWithoutNetwork() async {
        let provider = CountingAlertsProvider(
            snapshot: AlertsSnapshot(
                source: "test",
                serverCachedAt: Date(timeIntervalSince1970: 10),
                fetchedAt: Date(timeIntervalSince1970: 11),
                statuses: [
                    .kyivCity: .quiet,
                    .chernihiv: .alarm
                ]
            )
        )
        let controller = StatusController(region: .kyivCity, provider: provider)
        await controller.refresh()
        #expect(provider.fetchCount == 1)
        guard case .quiet = controller.state else {
            Issue.record("Expected quiet for Kyiv")
            return
        }

        controller.setRegion(.chernihiv)
        guard case let .alarm(checkedAt) = controller.state else {
            Issue.record("Expected alarm for Chernihiv from cache, got \(controller.state)")
            return
        }
        #expect(checkedAt == Date(timeIntervalSince1970: 10))
        #expect(controller.regionTitle == AlertRegion.chernihiv.title)

        for _ in 0 ..< 20 where provider.fetchCount < 2 {
            await Task.yield()
        }
        #expect(provider.fetchCount == 2)
    }

    @Test
    @MainActor
    func controller_missingRegion_isDistinctFromNetworkError() async {
        let provider = CountingAlertsProvider(
            snapshot: AlertsSnapshot(
                source: "test",
                serverCachedAt: Date(timeIntervalSince1970: 10),
                fetchedAt: Date(timeIntervalSince1970: 11),
                statuses: [.kyivCity: .quiet]
            )
        )
        let controller = StatusController(region: .kyivCity, provider: provider)
        await controller.refresh()
        controller.setRegion(.odesa)
        #expect(controller.state == .regionUnavailable)
        #expect(controller.state.title == "Region Unavailable")
        #expect(controller.state.phase != .error)
    }
}

@MainActor
private final class CountingAlertsProvider: StatusProviding {
    let snapshot: AlertsSnapshot
    private(set) var fetchCount = 0

    init(snapshot: AlertsSnapshot) {
        self.snapshot = snapshot
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        fetchCount += 1
        return snapshot
    }
}
