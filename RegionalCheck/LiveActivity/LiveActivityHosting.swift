// `@preconcurrency` because `ActivityKit.Activity` is a non-Sendable class whose `update` and `end`
// are nonisolated `async`, so Swift 6 reports calling them from the main actor as sending a
// non-Sendable value. Safe here: each `Activity` is held by one main-actor handle and only handed to
// ActivityKit's own off-actor API. Scoped to this file, the only one that touches `Activity`.
@preconcurrency import ActivityKit
import DriveCheckKit
import Foundation

typealias DriveCheckActivityContent = ActivityContent<DriveCheckActivityAttributes.ContentState>

/// The ActivityKit calls `LiveActivityController` makes, so tests replace the system and not the
/// controller.
@MainActor
protocol LiveActivityHosting {
    /// Activities the system still shows for this app, including ones requested by a previous
    /// process. Ended ones stay listed until dismissed and cannot be updated, so they are excluded.
    func runningActivities() -> [any LiveActivityHandle]
    func request(_ content: DriveCheckActivityContent) throws -> any LiveActivityHandle
}

@MainActor
protocol LiveActivityHandle: AnyObject {
    func update(_ content: DriveCheckActivityContent) async
    func end(_ content: DriveCheckActivityContent?, dismissal: ActivityUIDismissalPolicy) async
}

struct ActivityKitLiveActivityHost: LiveActivityHosting {
    func runningActivities() -> [any LiveActivityHandle] {
        Activity<DriveCheckActivityAttributes>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
            .map(ActivityKitLiveActivity.init)
    }

    func request(_ content: DriveCheckActivityContent) throws -> any LiveActivityHandle {
        let activity = try Activity.request(
            attributes: DriveCheckActivityAttributes(),
            content: content,
            pushType: nil
        )
        return ActivityKitLiveActivity(activity)
    }
}

@MainActor
private final class ActivityKitLiveActivity: LiveActivityHandle {
    private let activity: Activity<DriveCheckActivityAttributes>

    init(_ activity: Activity<DriveCheckActivityAttributes>) {
        self.activity = activity
    }

    func update(_ content: DriveCheckActivityContent) async {
        await activity.update(content)
    }

    func end(_ content: DriveCheckActivityContent?, dismissal: ActivityUIDismissalPolicy) async {
        await activity.end(content, dismissalPolicy: dismissal)
    }
}
