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
        let kind = switch self {
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

    func ageText(for snapshot: CarPlaySnapshot) -> String {
        ageText(since: snapshot.checkedAt)
    }

    /// Same "X min/h ago" wording as `ageText(for:)`, for a timestamp that isn't wrapped in a
    /// `CarPlaySnapshot` — the Map tab's own image `loadedAt`, independent of the alert status.
    func ageText(since date: Date) -> String {
        let minutes = max(1, Int(now.timeIntervalSince(date) / 60))
        if minutes < 60 {
            return String(format: String(localized: "driver.age.minutes"), minutes)
        }
        return String(format: String(localized: "driver.age.hours"), minutes / 60)
    }
}

enum CarPlayHeadline {
    static func title(for loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> String {
        switch loadState {
        case let .loaded(snapshot):
            // An upstream cache can itself be old; never present it as a bare current status.
            if freshness.isFresh(snapshot) {
                markedTitle(snapshot.state)
            } else {
                agedStatus(snapshot, freshness: freshness)
            }
        case let .loading(cached):
            if let cached, freshness.isFresh(cached) {
                markedTitle(cached.state)
            } else {
                String(localized: "driver.updating")
            }
        case let .failed(cached):
            if let cached, freshness.isFresh(cached) {
                markedTitle(cached.state)
            } else {
                "? \(String(localized: "driver.no_current_data"))"
            }
        }
    }

    /// Stale status without the colored marker, e.g. "No Alert · 25 min ago".
    static func agedStatus(_ snapshot: CarPlaySnapshot, freshness: CarPlayFreshness) -> String {
        "\(snapshot.state.title) · \(freshness.ageText(for: snapshot))"
    }

    static func marker(for state: StatusState) -> String {
        switch state {
        case .alarm: "🚨"
        case .quiet: "🟢"
        case .idle: "↻"
        case .error, .regionUnavailable: "?"
        }
    }

    private static func markedTitle(_ state: StatusState) -> String {
        "\(marker(for: state)) \(state.title)"
    }
}
