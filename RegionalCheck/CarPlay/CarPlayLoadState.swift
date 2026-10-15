import DriveCheckKit
import Foundation
import os

enum CarPlayLog {
    /// One category for the cold-launch path so a device session can be replayed with
    /// `log stream --predicate 'category == "carplay.lifecycle"'`.
    static let lifecycle = Logger(subsystem: "vil4max.RegionalCheck", category: "carplay.lifecycle")
}

struct CarPlaySnapshot: Equatable {
    let state: StatusState
    let regionTitle: String
    /// `AlertsSnapshot.checkedAt`, the same instant shown as "Updated:", so the
    /// freshness verdict and the visible time never disagree.
    let checkedAt: Date
}

/// Single source of truth for the CarPlay screen. Freshness is judged from the
/// snapshot timestamp, never from whether a request in this session failed.
enum CarPlayLoadState: Equatable {
    case loading(cached: CarPlaySnapshot?)
    case loaded(CarPlaySnapshot)
    case failed(cached: CarPlaySnapshot?)

    var snapshot: CarPlaySnapshot? {
        switch self {
        case let .loading(cached), let .failed(cached):
            cached
        case let .loaded(snapshot):
            snapshot
        }
    }

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    var logDescription: String {
        let kind =
            switch self {
            case .loading: "loading"
            case .loaded: "loaded"
            case .failed: "failed"
            }
        return "\(kind)(snapshot=\(snapshot.map { "\($0.state.phase)" } ?? "nil"))"
    }
}

struct CarPlayFreshness {
    let now: Date
    /// Base polling interval; `DataFreshness` applies the shared 2× stale threshold.
    let refreshIntervalSeconds: TimeInterval

    func isFresh(_ snapshot: CarPlaySnapshot) -> Bool {
        !DataFreshness.isStale(checkedAt: snapshot.checkedAt, now: now, refreshIntervalSeconds: refreshIntervalSeconds)
    }
}

enum CarPlayHeadline {
    static func marker(for state: StatusState) -> String {
        switch state {
        case .alarm: "🚨"
        case .quiet: "🟢"
        case .idle: "↻"
        case .error, .regionUnavailable: "?"
        }
    }
}
