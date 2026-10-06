import ActivityKit

/// Whether iOS lets Drive Check show Live Activities at all — the per-app switch in Settings
/// (https://developer.apple.com/documentation/activitykit/activityauthorizationinfo). It is a
/// separate thing from the app's own switch on Details, which decides whether a driving session
/// starts one; the Details tab reads this so its switch never promises what iOS refuses.
protocol LiveActivityPermissionSource: Sendable {
    var areActivitiesEnabled: Bool { get }
    /// The current Settings state after subscribing, followed by each change while the app runs.
    func enablementUpdates() -> AsyncStream<Bool>
}

struct SystemLiveActivityPermission: LiveActivityPermissionSource {
    private let currentValue: @Sendable () -> Bool
    private let updates: @Sendable () -> any AsyncSequence<Bool, Never>

    init(
        currentValue: @escaping @Sendable () -> Bool = { ActivityAuthorizationInfo().areActivitiesEnabled },
        updates: @escaping @Sendable () -> any AsyncSequence<Bool, Never> = {
            ActivityAuthorizationInfo().activityEnablementUpdates
        }
    ) {
        self.currentValue = currentValue
        self.updates = updates
    }

    var areActivitiesEnabled: Bool {
        currentValue()
    }

    func enablementUpdates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                var iterator = updates().makeAsyncIterator()
                // Read after creating the iterator to cover a change since the caller's earlier read.
                // ActivityKit replay is unverified; repeating this first Bool is harmless.
                continuation.yield(currentValue())
                while let enabled = await iterator.next(isolation: nil) {
                    continuation.yield(enabled)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
