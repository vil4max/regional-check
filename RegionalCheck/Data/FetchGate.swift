import DriveCheckKit
import Foundation

/// The two holds on a status fetch (REQ-REFRESH-005, REQ-REFRESH-010), kept apart from the
/// controller so they can be tested with plain dates.
struct FetchGate {
    /// Minimum spacing between network fetches (REQ-REFRESH-010). Above the provider's 3 s server
    /// cache, inside which a refetch returns identical data, and below the 27 s a scheduled alarm
    /// poll can reach after jitter, so the floor never swallows a scheduled poll.
    static let floor: TimeInterval = 10

    private(set) var rateLimitedUntil: Date?
    private(set) var lastSuccessAt: Date?

    func isRateLimited(now: Date) -> Bool {
        guard let rateLimitedUntil else { return false }
        return now < rateLimitedUntil
    }

    /// A rate-limit window holds scheduled polls only; the floor holds every trigger. The floor is
    /// measured from the last success, so retries after a failure keep the spacing
    /// REQ-REFRESH-003/004 give them. With no success yet a session's first fetch is immediate.
    func isHeld(isScheduled: Bool, now: Date) -> Bool {
        if isScheduled, isRateLimited(now: now) {
            return true
        }
        if let lastSuccessAt, now.timeIntervalSince(lastSuccessAt) < Self.floor {
            return true
        }
        return false
    }

    /// A manual success inside the window leaves it in place: the host asked for a pause, and
    /// one answered request does not show the pause is over.
    mutating func recordSuccess(at now: Date) {
        lastSuccessAt = now
    }

    /// Returns the deadline actually kept, capped like every other `Retry-After`.
    @discardableResult
    mutating func recordRateLimit(until: Date, now: Date) -> Date {
        let capped = min(until, now.addingTimeInterval(RetryAfterParser.maxHold))
        rateLimitedUntil = capped
        return capped
    }
}
