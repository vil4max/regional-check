import Foundation

/// REQ-REFRESH-006 (amended 2026-09-23): when iOS marks the Live Activity stale. The activity
/// cannot re-check while the app is not running, so this is a background horizon, not the 2×
/// refresh-interval rule: while the app or CarPlay runs, the app's own stale flag applies that
/// rule and each update moves this date forward.
enum LiveActivityStaleDate {
    static let backgroundHorizon: TimeInterval = 15 * 60

    static func make(checkedAt: Date?, now: Date = Date()) -> Date {
        let base = checkedAt ?? now
        return base.addingTimeInterval(backgroundHorizon)
    }
}
