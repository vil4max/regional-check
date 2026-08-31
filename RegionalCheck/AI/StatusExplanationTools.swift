import DriveCheckKit
import Foundation

/// An untrusted model request for deterministic code execution.
/// The model names an allowlisted tool; Swift validates and executes it.
struct ExplanationToolCall: Equatable, Sendable {
    let name: String
    let argumentsJSON: String
}

enum StatusExplanationToolName: String, CaseIterable, Sendable {
    case currentStatus = "get_current_status"
    case dataFreshness = "get_data_freshness"
}

struct StatusFactSheet: Equatable, Sendable, Codable {
    let regionID: String
    let regionTitle: String
    let status: String
    let checkedAt: Date
    let source: String
}

struct FreshnessFacts: Equatable, Sendable, Codable {
    let ageSeconds: TimeInterval
    let refreshIntervalSeconds: TimeInterval
    let isStale: Bool
}

enum ToolExecutionError: Error, Equatable {
    case unknownTool(String)
    case invalidArguments(String)
}

/// Deterministic read-only tool boundary for one bounded explanation run.
/// Every fact is derived in Swift from the seeded run state; freshness uses the
/// same RefreshPolicy thresholds as StatusController so the model cannot disagree
/// with the staleness the UI already shows.
struct StatusExplanationToolExecutor: Sendable {
    /// Immutable facts captured once when the run starts, so every tool result
    /// in the run reasons about one consistent view of application state.
    struct Seed: Sendable {
        let context: StatusExplanationContext
        let refreshIntervalSeconds: TimeInterval
    }

    let seed: Seed
    let now: @Sendable () -> Date

    func execute(_ call: ExplanationToolCall) throws -> String {
        guard let tool = StatusExplanationToolName(rawValue: call.name) else {
            throw ToolExecutionError.unknownTool(call.name)
        }
        guard Self.isValidEmptyArguments(call.argumentsJSON) else {
            throw ToolExecutionError.invalidArguments(call.argumentsJSON)
        }
        switch tool {
        case .currentStatus:
            return Self.encode(
                StatusFactSheet(
                    regionID: seed.context.regionID,
                    regionTitle: seed.context.regionTitle,
                    status: seed.context.phase == .quiet ? "all_clear" : "alert_active",
                    checkedAt: seed.context.checkedAt,
                    source: ModelStatusSource.publicAlertFeed
                )
            )
        case .dataFreshness:
            let currentTime = now()
            let age = max(0, currentTime.timeIntervalSince(seed.context.checkedAt))
            let facts = FreshnessFacts(
                ageSeconds: age,
                refreshIntervalSeconds: seed.refreshIntervalSeconds,
                isStale: DataFreshness.isStale(
                    checkedAt: seed.context.checkedAt,
                    now: currentTime,
                    refreshIntervalSeconds: seed.refreshIntervalSeconds
                )
            )
            return Self.encode(facts)
        }
    }

    /// Both v1 tools are argument-free; anything beyond an empty JSON object is rejected.
    private static func isValidEmptyArguments(_ json: String) -> Bool {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "{}"
    }

    private static func encode(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(value)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
