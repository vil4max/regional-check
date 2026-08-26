import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct FallbackStatusExplanationProviderTests {
    private func makeInput() -> StatusExplanationInput {
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = AlertsSnapshot(
            source: "feed",
            serverCachedAt: at,
            fetchedAt: at,
            statuses: [.kyivCity: .quiet]
        )
        return StatusExplanationInput(snapshot: snapshot, region: .kyivCity, status: .quiet(lastCheckedAt: at))
    }

    private struct StaticProvider: StatusExplanationProviding {
        let text: String
        func explanation(for _: StatusExplanationInput) async throws -> String {
            text
        }
    }

    private struct FailingProvider: StatusExplanationProviding {
        let error: any Error
        func explanation(for _: StatusExplanationInput) async throws -> String {
            throw error
        }
    }

    @Test
    func primarySuccessSkipsFallback() async throws {
        let store = ExplanationTraceStore()
        let provider = FallbackStatusExplanationProvider(
            primary: StaticProvider(text: "AI answer"),
            fallback: StaticProvider(text: "local"),
            trace: store
        )
        let result = try await provider.explanation(for: makeInput())
        #expect(result == "AI answer")
        let events = await store.recordedEvents()
        #expect(events.isEmpty)
    }

    @Test
    func runtimeFailureFallsBackWithTracedReason() async throws {
        let store = ExplanationTraceStore()
        let provider = FallbackStatusExplanationProvider(
            primary: FailingProvider(error: ExplanationRunError.stepLimitExceeded),
            fallback: LocalStatusExplanationProvider(),
            trace: store
        )
        let result = try await provider.explanation(for: makeInput())
        #expect(result == makeInput().status.explanation)
        let events = await store.recordedEvents()
        #expect(events.contains(.fallbackUsed(reason: "step_limit")))
    }

    @Test
    func arbitraryFailureMapsToTransportReason() async throws {
        struct Boom: Error {}
        let store = ExplanationTraceStore()
        let provider = FallbackStatusExplanationProvider(
            primary: FailingProvider(error: Boom()),
            fallback: StaticProvider(text: "deterministic"),
            trace: store
        )
        let result = try await provider.explanation(for: makeInput())
        #expect(result == "deterministic")
        let events = await store.recordedEvents()
        #expect(events.contains(.fallbackUsed(reason: "model_transport")))
    }

    @Test
    func cancellationPropagatesWithoutStaleFallback() async {
        let provider = FallbackStatusExplanationProvider(
            primary: FailingProvider(error: CancellationError()),
            fallback: StaticProvider(text: "must not appear")
        )
        await #expect(throws: CancellationError.self) {
            try await provider.explanation(for: makeInput())
        }
    }
}
