import DriveCheckKit

/// REQ-SURF-009: what the Live Activity's Refresh button does in the app process. It is the
/// driver's own refresh, so the in-process fetch floor holds it and a rate-limit window does not
/// (REQ-PROVIDER-002, REQ-REFRESH-005). The lifecycle policy then treats the result like any
/// other: an all-clear ends the activity, an alarm updates it, and a failure leaves it marked
/// stale. With no session it can adopt or end an activity, never start one.
@MainActor
final class LiveActivityRefresher: LiveActivityRefreshing {
    private let status: StatusController
    private let liveActivity: any LiveActivityControlling

    init(status: StatusController, liveActivity: any LiveActivityControlling) {
        self.status = status
        self.liveActivity = liveActivity
    }

    func refreshLiveActivity() async {
        await status.refresh()
        AppContainer.syncLiveActivityContent(status: status, liveActivity: liveActivity)
        // The intent finishes when this returns, and iOS may suspend the app right after, so the
        // ActivityKit update or end must already be done.
        await liveActivity.settle()
    }
}
