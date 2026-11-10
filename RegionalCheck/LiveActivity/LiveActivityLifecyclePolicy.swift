import DriveCheckKit
import Foundation

/// REQ-SURF-009: the activity follows the alert, not the app session. A session (the phone app
/// in the foreground, or CarPlay) is only needed to start one, because ActivityKit starts
/// activities from the foreground; after that only a confirmed all-clear ends it.
enum LiveActivityLifecyclePolicy {
    enum Action: Equatable {
        case none
        case start
        case update
        case terminate
        /// Take over an activity that outlived the process instead of requesting a second one.
        case adopt
        /// End activities that outlived the process once they no longer describe an alert.
        case endOrphans
    }

    /// `hasSystemActivities` is what the system still lists for this app. It only matters while
    /// this process owns no activity: after a termination the old activity is still on screen,
    /// and the new process starts with `hasActivity == false`.
    static func nextAction(
        canRun: Bool,
        phase: DriveCheckActivityPhase,
        hasSession: Bool,
        hasActivity: Bool,
        hasSystemActivities: Bool = false,
        isStale: Bool = false,
        isNewerThanActivity: Bool = true
    ) -> Action {
        guard canRun else {
            if hasActivity {
                return .terminate
            }
            return hasSystemActivities ? .endOrphans : .none
        }
        // Only `.quiet` is a confirmed all-clear. `.idle` and `.error` say nothing new about the
        // region, and a stale alarm must stay visible (REQ-REFRESH-006). A quiet status that is
        // stale, or older than what the activity shows (a saved status before the first refresh
        // after the server started the activity by push), is not an all-clear (ALERT-push point 3).
        let isAllClear = phase == .quiet && !isStale && isNewerThanActivity
        if hasActivity {
            return isAllClear ? .terminate : .update
        }
        if hasSystemActivities {
            if isAllClear {
                return .endOrphans
            }
            return phase == .alarm ? .adopt : .none
        }
        return phase == .alarm && hasSession ? .start : .none
    }
}
