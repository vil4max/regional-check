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
    /// ActivityKit's push-to-start token and its changes (ALERT-push AC-2).
    func pushToStartTokens() -> AsyncStream<Data>
    /// Every activity the system starts for this app, including one started by push while the
    /// app was not running (ALERT-push critic point 1).
    func newActivities() -> AsyncStream<any LiveActivityHandle>
}

@MainActor
protocol LiveActivityHandle: AnyObject {
    /// ActivityKit's identifier, so two wrappers of one activity compare equal.
    var activityID: String { get }
    /// The check time the activity shows now, whoever wrote it (the app or the server).
    var checkedAt: Date? { get }
    /// The update token the server needs to update and end this activity (AC-9).
    func pushTokens() -> AsyncStream<Data>
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
        // `.token`, so the server can update and end it when the app is not running (AC-9).
        let activity = try Activity.request(
            attributes: DriveCheckActivityAttributes(),
            content: content,
            pushType: .token
        )
        return ActivityKitLiveActivity(activity)
    }

    func pushToStartTokens() -> AsyncStream<Data> {
        AsyncStream { continuation in
            let task = Task {
                for await token in Activity<DriveCheckActivityAttributes>.pushToStartTokenUpdates {
                    continuation.yield(token)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func newActivities() -> AsyncStream<any LiveActivityHandle> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                for await activity in Activity<DriveCheckActivityAttributes>.activityUpdates {
                    continuation.yield(ActivityKitLiveActivity(activity))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
private final class ActivityKitLiveActivity: LiveActivityHandle {
    private let activity: Activity<DriveCheckActivityAttributes>

    init(_ activity: Activity<DriveCheckActivityAttributes>) {
        self.activity = activity
    }

    var activityID: String {
        activity.id
    }

    var checkedAt: Date? {
        activity.content.state.checkedAt
    }

    func pushTokens() -> AsyncStream<Data> {
        let activity = activity
        return AsyncStream { continuation in
            let task = Task {
                for await token in activity.pushTokenUpdates {
                    continuation.yield(token)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func update(_ content: DriveCheckActivityContent) async {
        await activity.update(content)
    }

    func end(_ content: DriveCheckActivityContent?, dismissal: ActivityUIDismissalPolicy) async {
        await activity.end(content, dismissalPolicy: dismissal)
    }
}
