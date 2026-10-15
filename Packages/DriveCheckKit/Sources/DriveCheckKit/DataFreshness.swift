import Foundation

/// The stale rule of REQ-REFRESH-006, shared by the app, CarPlay and the Siri answer: data is
/// stale once it is older than twice the base polling interval it was fetched under.
public enum DataFreshness {
    public static func isStale(checkedAt: Date, now: Date, refreshIntervalSeconds: TimeInterval) -> Bool {
        guard refreshIntervalSeconds > 0 else { return false }
        return now.timeIntervalSince(checkedAt) > refreshIntervalSeconds * 2
    }
}
