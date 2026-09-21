import ActivityKit

/// Whether iOS lets Drive Check show Live Activities at all — the per-app switch in Settings
/// (https://developer.apple.com/documentation/activitykit/activityauthorizationinfo). It is a
/// separate thing from the app's own switch on Details, which decides whether a driving session
/// starts one; the Details tab reads this so its switch never promises what iOS refuses.
protocol LiveActivityPermissionSource: Sendable {
    var areActivitiesEnabled: Bool { get }
    /// Each change of the Settings switch while the app runs.
    func enablementUpdates() -> AsyncStream<Bool>
}

struct SystemLiveActivityPermission: LiveActivityPermissionSource {
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func enablementUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
                    continuation.yield(enabled)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
