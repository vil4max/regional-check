import Foundation

/// The line a Live Activity shows under its state and region (REQ-SURF-014).
public enum LiveActivityDetail: Equatable, Sendable {
    /// "Started 12 minutes ago": a fresh alarm whose start the server knows. The system advances
    /// it without pushes.
    case started(Date)
    /// The time of the last check, for every other state that has one.
    case checked(Date)
    case none
}

extension DriveCheckActivityAttributes.ContentState {
    /// `isStale` is the activity's own staleness or the system's (`context.isStale`). A stale
    /// alarm may already be over (REQ-SURF-003), so it shows its check time and nothing counts.
    public func liveActivityDetail(isStale: Bool) -> LiveActivityDetail {
        if phase == .alarm, !isStale, let alertStartedAt {
            return .started(alertStartedAt)
        }
        if let checkedAt {
            return .checked(checkedAt)
        }
        return .none
    }
}
