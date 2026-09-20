import Foundation

enum LiveActivityLifecyclePolicy {
    enum Action: Equatable {
        case none
        case start
        case update
        case terminate
        /// Take over an activity that outlived the process instead of requesting a second one.
        case adopt
        /// End activities that outlived the process when nothing can keep them current.
        case endOrphans
    }

    /// `hasSystemActivities` is what the system still lists for this app. It only matters while
    /// this process owns no activity: after a termination the old activity is still on screen,
    /// frozen, and the new process starts with `hasActivity == false`.
    static func nextAction(
        canRun: Bool,
        hasClients: Bool,
        hasActivity: Bool,
        hasSystemActivities: Bool = false
    ) -> Action {
        let wantsActivity = canRun && hasClients
        if hasActivity {
            return wantsActivity ? .update : .terminate
        }
        if hasSystemActivities {
            return wantsActivity ? .adopt : .endOrphans
        }
        return wantsActivity ? .start : .none
    }
}
