import DriveCheckKit
import SwiftUI

/// STATUS-reason: the hero's one line saying why the status is what it is. While the region is
/// quiet it names the neighbours under alert (REQ-SURF-005), the note next to "No Alert"
/// (STATUS-two-states); during the region's own alert it gives the alert's start from the response
/// (REQ-SURF-014) instead. Gated on the phase, not the accent, so stale data keeps the line: the
/// meta line right under it states the data's age.
enum StatusReasonLine {
    @MainActor
    static func text(
        region: AlertRegion,
        phase: StatusState.Phase,
        snapshot: AlertsSnapshot?,
        alarmStartedAt: Date?,
        checkedAt: Date?,
        allClear: AllClearRecord? = nil
    ) -> String? {
        guard snapshot != nil else { return nil }
        switch phase {
        case .quiet:
            let nearby = NearbyAlertsLine.regions(near: region, snapshot: snapshot)
            guard nearby.isEmpty else {
                return String(format: String(localized: "status.reason.nearby"), NearbyAlertsLine.names(nearby))
            }
            return allClearText(allClear, region: region, checkedAt: checkedAt)
        case .alarm:
            guard let alarmStartedAt else { return nil }
            let time = DayAwareTime.text(alarmStartedAt, reference: checkedAt ?? alarmStartedAt)
            return String(format: String(localized: "status.reason.since"), time)
        case .idle, .error, .regionUnavailable:
            return nil
        }
    }

    /// The all-clear the app saw, for 30 minutes after it (owner: «30 минут»), measured against the
    /// data's check time like the "since" date, so it moves with every refresh.
    static let allClearShownFor: TimeInterval = 30 * 60

    private static func allClearText(_ record: AllClearRecord?, region: AlertRegion, checkedAt: Date?) -> String? {
        guard let record, record.region == region, let checkedAt else { return nil }
        let age = checkedAt.timeIntervalSince(record.allClearAt)
        guard age >= 0, age < allClearShownFor else { return nil }
        let time = DayAwareTime.text(record.allClearAt, reference: checkedAt)
        guard let minutes = record.durationMinutes else {
            return String(format: String(localized: "status.reason.allclear.time"), time)
        }
        return String(format: String(localized: "status.reason.allclear"), time, minutes)
    }
}
