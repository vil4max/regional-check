import Foundation
import Testing
import RegionalCheckData
import RegionalCheckDomain
import RegionalCheckStatus

struct SmokeTests {
    @Test
    func useCase_returnsProviderSnapshot() async throws {
        let provider = MockAirAlertProvider { region in
            AlertStatusSnapshot(
                region: region,
                status: .quiet,
                checkedAt: Date(timeIntervalSince1970: 1),
                source: "test"
            )
        }
        let fixedNow = Date(timeIntervalSince1970: 42)
        let useCase = FetchAlertStatusUseCase(provider: provider, now: { fixedNow })

        let snapshot = try await useCase.execute(region: .kyivCity)
        #expect(snapshot.status == .quiet)
        #expect(snapshot.checkedAt == fixedNow)
        #expect(snapshot.source == "test")
    }

    @Test
    @MainActor
    func viewModel_mapsProviderStates() async {
        let provider = MockAirAlertProvider { region in
            AlertStatusSnapshot(
                region: region,
                status: .alarm,
                checkedAt: Date(timeIntervalSince1970: 1),
                source: "test"
            )
        }
        let useCase = FetchAlertStatusUseCase(provider: provider, now: { Date(timeIntervalSince1970: 100) })
        let viewModel = RegionalCheckViewModel(region: .kyivCity, fetchStatus: useCase)

        viewModel.refresh()
        await waitUntilReady(viewModel: viewModel)

        guard case .alarm(let lastCheckedAt, let source) = viewModel.state else {
            Issue.record("Expected attention/alarm state, got \(viewModel.state)")
            return
        }
        #expect(source == "test")
        #expect(lastCheckedAt == Date(timeIntervalSince1970: 100))
    }

    @Test
    @MainActor
    func viewModel_mapsFailureToUnableToUpdate() async {
        struct TestError: Error {}
        let provider = MockAirAlertProvider { _ in throw TestError() }
        let useCase = FetchAlertStatusUseCase(provider: provider)
        let viewModel = RegionalCheckViewModel(region: .kyivCity, fetchStatus: useCase)

        viewModel.refresh()
        await waitUntilReady(viewModel: viewModel)

        guard case .error(let message) = viewModel.state else {
            Issue.record("Expected unable-to-update state, got \(viewModel.state)")
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
        let provider = UbillingAirAlertProvider(httpClient: http, now: { Date(timeIntervalSince1970: 123) })

        let snapshot = try await provider.fetchStatus(region: .kyivCity)
        #expect(snapshot.status == .alarm)
        #expect(snapshot.source == "test")
        #expect(snapshot.checkedAt == Date(timeIntervalSince1970: 123))
    }
}

private struct MockAirAlertProvider: AirAlertProviding {
    let statusForRegion: @Sendable (AlertRegion) async throws -> AlertStatusSnapshot

    init(statusForRegion: @escaping @Sendable (AlertRegion) async throws -> AlertStatusSnapshot) {
        self.statusForRegion = statusForRegion
    }

    func fetchStatus(region: AlertRegion) async throws -> AlertStatusSnapshot {
        try await statusForRegion(region)
    }

    func fetchAllOblastStatuses() async throws -> [AlertStatusSnapshot] {
        []
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
private func waitUntilReady(viewModel: RegionalCheckViewModel) async {
    for _ in 0..<50 {
        if case .idle = viewModel.state {
            await Task.yield()
            continue
        }
        return
    }
    Issue.record("Timed out waiting for view model state update")
}
