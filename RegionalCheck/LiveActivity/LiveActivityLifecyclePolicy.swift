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
        hasSystemActivities: Bool = false
    ) -> Action {
        guard canRun else {
            if hasActivity {
                return .terminate
            }
            return hasSystemActivities ? .endOrphans : .none
        }
        // Only `.quiet` is a confirmed all-clear. `.idle` and `.error` say nothing new about the
        // region, and a stale alarm must stay visible (REQ-REFRESH-006).
        let isAllClear = phase == .quiet
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
