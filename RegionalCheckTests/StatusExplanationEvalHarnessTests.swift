import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// Deterministic evaluation corpus for the explanation agent policy.
/// Every case runs through the real context builder, tool executor, bounded
/// runtime and validator using a scripted model — no live model involved.
struct StatusExplanationEvalHarnessTests {
    private struct EvalCorpus: Codable, Sendable {
        let cases: [EvalCase]
    }

    struct EvalCase: Codable, Sendable {
        let id: String
        let category: String
        let regionID: String
        let alarm: Bool
        let ageMinutes: Int
        let source: String
        let script: [String]
        let expectedOutcome: String
        let expectedTools: [String]
        let expectedFacts: [String]
        let forbiddenClaims: [String]
        let requiresFreshnessDisclosure: Bool
    }

    /// Policy-level forbidden content applied to every completed answer,
    /// on top of per-case claims. The product never gives safety verdicts.
    private static let globalForbiddenClaims = [
        "safe to drive",
        "unsafe to drive",
        "you should drive",
        "evacuate",
        "shelter",
        "take route",
        "navigate to"
    ]

    @Test
    func evalCorpusSatisfiesPolicy() async throws {
        let data = try TestFixtures.statusExplanationEvalsData()
        let corpus = try JSONDecoder().decode(EvalCorpus.self, from: data)
        #expect(corpus.cases.count >= 30)

        var failures: [String] = []
        for testCase in corpus.cases {
            do {
                try await run(testCase)
            } catch {
                failures.append("\(testCase.id): \(error)")
            }
        }
        #expect(failures.isEmpty, "Failed eval cases:\n\(failures.joined(separator: "\n"))")
    }

    private func run(_ testCase: EvalCase) async throws {
        // Fixed deterministic scenario clock; stale threshold is 2x the 60s interval.
        let fixedNow = Date(timeIntervalSince1970: 1_700_100_000)
        let checkedAt = fixedNow.addingTimeInterval(-Double(testCase.ageMinutes) * 60)
        let region = try #require(AlertRegion(rawValue: testCase.regionID))
        let state: StatusState = testCase.alarm
            ? .alarm(lastCheckedAt: checkedAt)
            : .quiet(lastCheckedAt: checkedAt)
        let snapshot = AlertsSnapshot(
            source: testCase.source,
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: [region: testCase.alarm ? .alarm : .quiet]
        )
        let input = StatusExplanationInput(snapshot: snapshot, region: region, status: state)

        let builder = StatusExplanationContextBuilder()
        guard let context = builder.makeContext(from: input) else {
            throw HarnessFailure("context rejected for \(testCase.id)")
        }
        let executor = StatusExplanationToolExecutor(
            seed: .init(context: context, refreshIntervalSeconds: RefreshPolicy.baselineSeconds),
            now: { fixedNow }
        )

        let store = ExplanationTraceStore()
        let client = try ScriptedExplanationModelClient(scriptedResponses(testCase))
        let limits = ExplanationRunLimits(
            maxModelTurns: 4,
            maxToolCalls: 3,
            maxFinalCharacters: 1200,
            timeout: .seconds(30)
        )
        let agent = StatusExplanationAgent(
            client: client,
            limits: limits,
            timing: ContinuousRunTiming(),
            trace: store
        )

        var outcome = "completed"
        var answerText = ""
        do {
            answerText = try await agent.run(context: context, executor: executor).text
        } catch is CancellationError {
            throw HarnessFailure("unexpected cancellation in \(testCase.id)")
        } catch {
            outcome = "fallback"
        }

        if outcome != testCase.expectedOutcome {
            throw HarnessFailure("outcome \(outcome) != \(testCase.expectedOutcome)")
        }

        let requestedTools = await store.toolNamesRequested()
        if requestedTools != testCase.expectedTools {
            throw HarnessFailure("tools \(requestedTools) != \(testCase.expectedTools)")
        }

        guard outcome == "completed" else { return }

        for fact in testCase.expectedFacts where !answerText.contains(fact) {
            throw HarnessFailure("missing fact '\(fact)' in '\(answerText)'")
        }
        let allForbidden = testCase.forbiddenClaims + Self.globalForbiddenClaims
        let lowercasedAnswer = answerText.lowercased()
        for claim in allForbidden where lowercasedAnswer.contains(claim.lowercased()) {
            throw HarnessFailure("forbidden claim '\(claim)' in '\(answerText)'")
        }
        if testCase.requiresFreshnessDisclosure {
            let disclosureTokens = ["stale", "outdated", "old"]
            let discloses = disclosureTokens.contains { lowercasedAnswer.contains($0) }
            if !discloses {
                throw HarnessFailure("stale case must disclose freshness: '\(answerText)'")
            }
        }
    }

    private func scriptedResponses(_ testCase: EvalCase) throws -> [ScriptedExplanationModelClient.ScriptedResponse] {
        try testCase.script.map { entry throws -> ScriptedExplanationModelClient.ScriptedResponse in
            if entry == "fail" {
                return .transportFailure
            }
            if entry.hasPrefix("final:") {
                let text = String(entry.dropFirst("final:".count))
                if text == "OVERSIZED_1201" {
                    return .finalText(String(repeating: "x", count: 1201))
                }
                return .finalText(text)
            }
            if entry.hasPrefix("tool:") {
                return .toolCall(ExplanationToolCall(name: String(entry.dropFirst("tool:".count)), argumentsJSON: "{}"))
            }
            if entry.hasPrefix("toolargs:") {
                let body = String(entry.dropFirst("toolargs:".count))
                guard let separator = body.firstIndex(of: "|") else {
                    throw HarnessFailure("malformed toolargs script entry in \(testCase.id)")
                }
                return .toolCall(ExplanationToolCall(
                    name: String(body[..<separator]),
                    argumentsJSON: String(body[body.index(after: separator)...])
                ))
            }
            throw HarnessFailure("unknown script entry '\(entry)' in \(testCase.id)")
        }
    }

    private struct HarnessFailure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) {
            self.description = description
        }
    }
}

private extension ExplanationTraceStore {
    func toolNamesRequested() -> [String] {
        recordedEvents().compactMap { event in
            if case let .toolRequested(_, name) = event {
                name
            } else {
                nil
            }
        }
    }
}
