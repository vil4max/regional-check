import Foundation
import Testing
@testable import RegionalCheck

struct SmokeTests {
    @Test
    @MainActor
    func controller_mapsProviderStates() async {
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
            Issue.record("Expected attention/alarm state, got \(controller.state)")
            return
        }
        #expect(source == "test")
        #expect(lastCheckedAt == Date(timeIntervalSince1970: 100))
    }

    @Test
    @MainActor
    func controller_mapsFailureToUnableToUpdate() async {
        struct TestError: Error {}
        let provider = MockStatusProvider { _ in throw TestError() }
        let controller = StatusController(region: .kyivCity, provider: provider)

        controller.refresh()
        await waitUntilReady(controller: controller)

        guard case .error(let message) = controller.state else {
            Issue.record("Expected unable-to-update state, got \(controller.state)")
            return
        }
        #expect(message == "Unable to update")
    }

    @Test
    func provider_mapsKyivAlarmFromJSON() async throws {
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
        let response = HTTPURLResponse(
            url: URL(string: "https://ubilling.net.ua/aerialalerts/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let http = MockHTTPClient(result: .success(data, response))
        let provider = UbillingProvider(httpClient: http, now: { Date(timeIntervalSince1970: 123) })

        let snapshot = try await provider.fetchStatus(region: .kyivCity)
        #expect(snapshot.status == .alarm)
        #expect(snapshot.source == "test")
        #expect(snapshot.checkedAt == Date(timeIntervalSince1970: 123))
    }
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
