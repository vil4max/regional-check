import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct StatusExplanationToolExecutorTests {
    private let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let currentTime = Date(timeIntervalSince1970: 1_700_000_060)

    private func makeSeed(
        phase: StatusExplanationContext.Phase = .quiet,
        refreshIntervalSeconds: TimeInterval = 60
    ) -> StatusExplanationToolExecutor.Seed {
        StatusExplanationToolExecutor.Seed(
            context: StatusExplanationContext(
                regionID: "kyivCity",
                regionTitle: "Kyiv",
                phase: phase,
                source: "test-feed",
                checkedAt: checkedAt
            ),
            refreshIntervalSeconds: refreshIntervalSeconds
        )
    }

    private func makeExecutor(
        seed: StatusExplanationToolExecutor.Seed,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_700_000_060) }
    ) -> StatusExplanationToolExecutor {
        StatusExplanationToolExecutor(seed: seed, now: now)
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    @Test
    func currentStatusReturnsDeterministicFactSheet() throws {
        let executor = makeExecutor(seed: makeSeed())
        let payload = try executor.execute(ExplanationToolCall(name: "get_current_status", argumentsJSON: "{}"))
        let decoded = try makeDecoder().decode(StatusFactSheet.self, from: Data(payload.utf8))
        #expect(decoded.regionID == "kyivCity")
        #expect(decoded.regionTitle == "Kyiv")
        #expect(decoded.status == "all_clear")
        #expect(decoded.source == "test-feed")
    }

    @Test
    func currentStatusReflectsAlarmPhase() throws {
        let executor = makeExecutor(seed: makeSeed(phase: .alarm))
        let payload = try executor.execute(ExplanationToolCall(name: "get_current_status", argumentsJSON: "{}"))
        #expect(payload.contains("alert_active"))
    }

    @Test
    func freshnessComputesAgeAndStalenessWithPolicyRule() throws {
        // Age 60s against a 60s interval: not yet stale (< 2x interval).
        let executor = makeExecutor(seed: makeSeed(refreshIntervalSeconds: 60), now: { currentTime })
        let payload = try executor.execute(ExplanationToolCall(name: "get_data_freshness", argumentsJSON: "{}"))
        let decoded = try makeDecoder().decode(FreshnessFacts.self, from: Data(payload.utf8))
        #expect(decoded.ageSeconds == 60)
        #expect(decoded.refreshIntervalSeconds == 60)
        #expect(!decoded.isStale)
    }

    @Test
    func freshnessFlagsStaleBeyondDoubleInterval() throws {
        // Same rule as StatusController.isDataStale: age > 2x interval.
        let late = Date(timeIntervalSince1970: 1_700_000_121)
        let executor = makeExecutor(seed: makeSeed(refreshIntervalSeconds: 60), now: { late })
        let payload = try executor.execute(ExplanationToolCall(name: "get_data_freshness", argumentsJSON: "{}"))
        let decoded = try makeDecoder().decode(FreshnessFacts.self, from: Data(payload.utf8))
        #expect(decoded.isStale)
    }

    @Test
    func unknownToolIsRejected() {
        let executor = makeExecutor(seed: makeSeed())
        #expect(throws: ToolExecutionError.unknownTool("delete_everything")) {
            try executor.execute(ExplanationToolCall(name: "delete_everything", argumentsJSON: "{}"))
        }
    }

    @Test(arguments: ["{\"region\": \"lviv\"}", "[1]", "\"x\""])
    func malformedArgumentsAreRejected(json: String) {
        let executor = makeExecutor(seed: makeSeed())
        #expect(throws: ToolExecutionError.invalidArguments(json)) {
            try executor.execute(ExplanationToolCall(name: "get_current_status", argumentsJSON: json))
        }
    }

    @Test(arguments: ["{}", "  {}  ", ""])
    func emptyArgumentVariantsAreAccepted(json: String) throws {
        let executor = makeExecutor(seed: makeSeed())
        let payload = try executor.execute(ExplanationToolCall(name: "get_current_status", argumentsJSON: json))
        #expect(payload.contains("all_clear"))
    }
}
