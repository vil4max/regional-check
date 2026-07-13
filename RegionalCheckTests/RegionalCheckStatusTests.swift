import Foundation
import Testing
import RegionalCheckDomain
import RegionalCheckStatus

struct AlertStatusUseCasesTests {
    @Test
    func fetchAlertStatusUseCase_setsCheckedAtFromClock() async throws {
        let provider = MockAirAlertProvider(
            statusForRegion: { region in
                AlertStatusSnapshot(region: region, status: .quiet, checkedAt: Date(timeIntervalSince1970: 1), source: "test")
            }
        )
        let fixedNow = Date(timeIntervalSince1970: 42)
        let useCase = FetchAlertStatusUseCase(provider: provider, now: { fixedNow })
        
        let snapshot = try await useCase.execute(region: .kyivCity)
        #expect(snapshot.checkedAt == fixedNow)
        #expect(snapshot.source == "test")
    }
    
    @Test
    @MainActor
    func viewModel_mapsQuietToState() async {
        let provider = MockAirAlertProvider(
            statusForRegion: { region in
                AlertStatusSnapshot(region: region, status: .alarm, checkedAt: Date(timeIntervalSince1970: 1), source: "test")
            }
        )
        let useCase = FetchAlertStatusUseCase(provider: provider, now: { Date(timeIntervalSince1970: 100) })
        let viewModel = RegionalCheckViewModel(region: .kyivCity, fetchStatus: useCase)
        
        viewModel.refresh()
        await spinUntilNotIdle(viewModel: viewModel)
        
        guard case .alarm(let lastCheckedAt, let source) = viewModel.state else {
            Issue.record("Expected alarm state, got \(viewModel.state)")
            return
        }
        #expect(source == "test")
        #expect(lastCheckedAt == Date(timeIntervalSince1970: 100))
    }
    
    @Test
    @MainActor
    func viewModel_mapsErrorsToState() async {
        struct TestError: Error {}
        let provider = MockAirAlertProvider(
            statusForRegion: { _ in throw TestError() }
        )
        let useCase = FetchAlertStatusUseCase(provider: provider)
        let viewModel = RegionalCheckViewModel(region: .kyivCity, fetchStatus: useCase)
        
        viewModel.refresh()
        await spinUntilNotIdle(viewModel: viewModel)
        
        guard case .error(let message) = viewModel.state else {
            Issue.record("Expected error state, got \(viewModel.state)")
            return
        }
        
        #expect(message == "Unable to update")
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

@MainActor
private func spinUntilNotIdle(viewModel: RegionalCheckViewModel) async {
    for _ in 0..<50 {
        if case .idle = viewModel.state {
            await Task.yield()
            continue
        }
        return
    }
    Issue.record("Timed out waiting for view model state update")
}

