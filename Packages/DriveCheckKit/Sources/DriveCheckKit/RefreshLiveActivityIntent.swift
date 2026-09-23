import AppIntents
import Foundation

/// The app-side work behind the Live Activity's Refresh button. The app registers it with
/// `AppDependencyManager`; the widget extension only compiles the intent, because iOS performs a
/// `LiveActivityIntent` in the app process.
@MainActor
public protocol LiveActivityRefreshing: AnyObject, Sendable {
    func refreshLiveActivity() async
}

/// REQ-SURF-009: the Live Activity's Refresh button. iOS performs a `LiveActivityIntent` in the
/// app process without opening the app, so the app can re-check the region and end the activity
/// on a confirmed all-clear with no server. The widget's own refresh stays `RefreshStatusIntent`,
/// which runs in the extension (rejected for 3.1.0: moving every widget tap into an app launch).
public struct RefreshLiveActivityIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "intent.refresh.title"
    /// Only the button on the activity runs it; Shortcuts already has the check-status intent.
    public static let isDiscoverable = false

    @Dependency private var refresher: any LiveActivityRefreshing

    public init() {}

    public func perform() async throws -> some IntentResult {
        await refresher.refreshLiveActivity()
        return .result()
    }
}
