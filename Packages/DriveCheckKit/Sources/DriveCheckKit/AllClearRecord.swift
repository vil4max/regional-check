import Foundation

/// STATUS-two-states AC-9: the last all-clear the app saw for the driver's region. The feed has no
/// all-clear time (a clear region's `changed` is the cache time), so the app records the moment
/// itself when it sees the region go from alert to quiet. One record, never a history list.
public struct AllClearRecord: Codable, Equatable, Sendable {
    public let region: AlertRegion
    /// The check time of the first response that showed the region quiet.
    public let allClearAt: Date
    /// The alert's start from the feed (REQ-SURF-014), when it was known.
    public let alertStartedAt: Date?

    public init(region: AlertRegion, allClearAt: Date, alertStartedAt: Date?) {
        self.region = region
        self.allClearAt = allClearAt
        self.alertStartedAt = alertStartedAt
    }

    /// The record after an accepted snapshot: a new one when `region` went from alert to quiet,
    /// none while it is under alert again, and otherwise the record as it was.
    public static func next(
        _ record: AllClearRecord?, region: AlertRegion, previous: AlertsSnapshot?, current: AlertsSnapshot
    ) -> AllClearRecord? {
        switch current.status(for: region) {
        case .alarm:
            return record?.region == region ? nil : record
        case .quiet where previous?.status(for: region) == .alarm:
            return AllClearRecord(
                region: region, allClearAt: current.checkedAt, alertStartedAt: previous?.alarmStart(for: region))
        default:
            return record
        }
    }

    /// Whole minutes the alert lasted, at least 1; nil when its start is unknown.
    public var durationMinutes: Int? {
        alertStartedAt.map { max(1, Int(allClearAt.timeIntervalSince($0) / 60)) }
    }
}
