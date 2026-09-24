import Foundation

/// The Details tab's own state (ADR 0015): what the settings rows show and where their actions
/// go. The summary above them keeps its own `StatusDetailsViewModel`.
@MainActor
@Observable
final class DetailsViewModel {
    private let location: any HomeLocationSource
    private let subscription: any SubscriptionManaging
    private let liveActivityPermission: any LiveActivityPermissionSource
    private let applyLiveActivityEnabled: (Bool) -> Void

    /// Whether iOS Settings allows this app's Live Activities (REQ-SURF-008).
    private(set) var isLiveActivityAllowedBySystem: Bool

    /// `setLiveActivityEnabled` is injected rather than sent to `subscription` directly: turning
    /// the switch also starts or ends the running activity, which `MainTabViewModel` owns.
    init(
        location: any HomeLocationSource,
        subscription: any SubscriptionManaging,
        liveActivityPermission: any LiveActivityPermissionSource,
        setLiveActivityEnabled: @escaping (Bool) -> Void
    ) {
        self.location = location
        self.subscription = subscription
        self.liveActivityPermission = liveActivityPermission
        applyLiveActivityEnabled = setLiveActivityEnabled
        isLiveActivityAllowedBySystem = liveActivityPermission.areActivitiesEnabled
    }

    var isLocationAccessBlocked: Bool {
        location.isAuthorizationBlocked
    }

    /// The driver's own choice, kept as it is while iOS refuses activities, so it comes back
    /// when Settings allows them again.
    var isLiveActivityEnabled: Bool {
        subscription.state.isLiveActivityEnabled
    }

    /// What the switch shows: never "on" while iOS refuses, because an "on" switch promises a
    /// Lock Screen activity that cannot appear (REQ-SURF-008).
    var isLiveActivitySwitchOn: Bool {
        isLiveActivityEnabled && isLiveActivityAllowedBySystem
    }

    /// Re-reads the Settings switch, then follows its changes for as long as the caller's task
    /// lives. The view runs this while Details is shown, so a driver returning from Settings sees
    /// the switch they just flipped.
    func observeLiveActivityPermission() async {
        refreshLiveActivityPermission()
        for await enabled in liveActivityPermission.enablementUpdates() {
            isLiveActivityAllowedBySystem = enabled
        }
    }

    func refreshLiveActivityPermission() {
        isLiveActivityAllowedBySystem = liveActivityPermission.areActivitiesEnabled
    }

    func setLiveActivityEnabled(_ enabled: Bool) {
        applyLiveActivityEnabled(enabled)
    }

    var versionBuildText: String {
        let info = Bundle.main.infoDictionary
        return Self.versionBuildText(
            version: info?["CFBundleShortVersionString"] as? String ?? "—",
            build: info?["CFBundleVersion"] as? String ?? "—"
        )
    }

    nonisolated static func versionBuildText(version: String, build: String) -> String {
        String(format: String(localized: "about.version_build %@ %@"), version, build)
    }
}
