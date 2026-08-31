import DriveCheckKit
import Foundation
import FoundationModels
@testable import RegionalCheck
import Testing

@MainActor
struct FoundationModelsExplanationProviderTests {
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

    private static let environment = RefreshEnvironment(
        isAlarmActive: false,
        isLowPowerModeEnabled: false,
        thermalState: .nominal,
        isExpensiveNetwork: false,
        isConstrainedNetwork: false
    )

    @Test
    func unavailableModelDegradesToDeterministicFallback() async throws {
        let store = ExplanationTraceStore()
        let primary = FoundationModelsExplanationProvider(
            environment: { Self.environment },
            trace: store,
            availability: { .unavailable(.deviceNotEligible) }
        )
        let composite = FallbackStatusExplanationProvider(
            primary: primary,
            fallback: LocalStatusExplanationProvider(),
            trace: store
        )

        // On ineligible devices the product stays fully useful without AI.
        let result = try await composite.explanation(for: makeInput())
        #expect(result == makeInput().status.explanation)
        let events = await store.recordedEvents()
        #expect(events.contains(.fallbackUsed(reason: "model_transport")))
    }

    @Test
    func modelPromptHidesRawUpstreamSource() {
        let rawSource = "Vadym Klymenko API (default)"
        let at = Date(timeIntervalSince1970: 1_700_000_000)
        let context = StatusExplanationContext(
            regionID: AlertRegion.kyivCity.rawValue,
            regionTitle: AlertRegion.kyivCity.title,
            phase: .quiet,
            source: rawSource,
            checkedAt: at
        )

        let prompt = StatusExplanationAgent.userPrompt(for: context)

        #expect(prompt.contains("source: public_alert_feed"))
        #expect(!prompt.contains(rawSource))
    }

    @Test
    func toolBudgetIsEnforced() async throws {
        let budget = ToolCallBudget(maxCalls: 2)
        try await budget.consume()
        try await budget.consume()
        await #expect(throws: ExplanationRunError.toolLimitExceeded) {
            try await budget.consume()
        }
        let used = await budget.usedCount
        #expect(used == 2)
    }

    @Test
    func transportNormalizerPassesThroughTypedAndUnknownErrors() {
        // Direct runtime errors keep their identity.
        #expect(ExplanationTransportNormalizer.normalized(ExplanationRunError.toolLimitExceeded) == .toolLimitExceeded)
        // Unknown transport failures stay unclassified for the fallback reason.
        struct OpaqueTransportError: Error {}
        #expect(ExplanationTransportNormalizer.normalized(OpaqueTransportError()) == nil)
        // The ToolCallError wrapping path is pinned by device validation
        // (docs/ai-explanation-runtime.md): underlyingError carries our typed error.
    }
}
