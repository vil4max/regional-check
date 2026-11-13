import DriveCheckKit
import Foundation

/// STATUS-two-states AC-9: the last all-clear the app saw for the driver's region. The feed has no
/// all-clear time (a clear region's `changed` is the cache time), so the app records the moment
/// itself when it sees the region go from alert to quiet. One record, never a history list.
struct AllClearRecord: Codable, Equatable, Sendable {
    let region: AlertRegion
    /// The check time of the first response that showed the region quiet.
    let allClearAt: Date
    /// The alert's start from the feed (REQ-SURF-014), when it was known.
    let alertStartedAt: Date?

    /// Two checks further apart than the data's freshness limit did not see the alert end: the
    /// all-clear fell somewhere in between, so its time and the alert's length would be invented.
    static let maxObservationGap = WidgetTimelineBuilder.defaultExpiredThreshold

    /// The record after an accepted snapshot: a new one when `region` went from alert to quiet
    /// between two close checks, none while it is under alert again, and otherwise the record as
    /// it was.
    static func next(
        _ record: AllClearRecord?, region: AlertRegion, previous: AlertsSnapshot?, current: AlertsSnapshot
    ) -> AllClearRecord? {
        switch current.status(for: region) {
        case .alarm:
            return record?.region == region ? nil : record
        case .quiet where previous?.status(for: region) == .alarm:
            guard let previous, current.checkedAt.timeIntervalSince(previous.checkedAt) <= maxObservationGap else {
                return record?.region == region ? nil : record
            }
            return AllClearRecord(
                region: region, allClearAt: current.checkedAt, alertStartedAt: previous.alarmStart(for: region))
        default:
            return record
        }
    }

    /// Whole minutes the alert lasted, at least 1; nil when its start is unknown.
    var durationMinutes: Int? {
        alertStartedAt.map { max(1, Int(allClearAt.timeIntervalSince($0) / 60)) }
    }
}

/// The record lives in the app's own defaults, not the App Group: no extension shows it (AC-4), so
/// the shared contract with the widgets, the control and Siri does not grow.
struct AllClearRecordStore {
    static let key = "status.allClear.v1"

    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
    }

    func load() -> AllClearRecord? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(AllClearRecord.self, from: data)
    }

    func save(_ record: AllClearRecord?) {
        guard let record, let data = try? JSONEncoder().encode(record) else {
            defaults.removeObject(forKey: Self.key)
            return
        }
        defaults.set(data, forKey: Self.key)
    }
}
