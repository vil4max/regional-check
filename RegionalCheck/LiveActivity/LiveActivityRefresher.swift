import DriveCheckKit

/// REQ-SURF-009: what the Live Activity's Refresh button does in the app process. It is the
/// driver's own refresh, so the in-process fetch floor holds it and a rate-limit window does not
/// (REQ-PROVIDER-002, REQ-REFRESH-005). The lifecycle policy then treats the result like any
/// other: an all-clear ends the activity, an alarm updates it, and a failure leaves it marked
/// stale. With no session it can adopt or end an activity, never start one.
@MainActor
final class LiveActivityRefresher: LiveActivityRefreshing {
    /// iOS gives an intent a limited run time and does not publish it. A fetch that outlasts this
    /// budget is cancelled, which is not a failure (the held snapshot and its age stay), so the
    /// activity is still brought up to date with what the app knows before the intent ends.
    static let fetchBudget: Duration = .seconds(8)

    private let status: StatusController
    private let liveActivity: any LiveActivityControlling
    private let fetchBudget: Duration
    private let sleeping: any BoundedAwait.Sleeping

    init(
        status: StatusController,
        liveActivity: any LiveActivityControlling,
        fetchBudget: Duration = LiveActivityRefresher.fetchBudget,
        sleeping: any BoundedAwait.Sleeping = BoundedAwait.ContinuousSleeping()
    ) {
        self.status = status
        self.liveActivity = liveActivity
        self.fetchBudget = fetchBudget
        self.sleeping = sleeping
    }

    func refreshLiveActivity() async {
        let status = status
        _ = try? await BoundedAwait.value(timeout: fetchBudget, sleeping: sleeping) { @MainActor in
            await status.refresh()
        }
        AppContainer.syncLiveActivityContent(status: status, liveActivity: liveActivity)
        // The intent finishes when this returns, and iOS may suspend the app right after, so the
        // ActivityKit update or end must already be done.
        await liveActivity.settle()
    }
}
