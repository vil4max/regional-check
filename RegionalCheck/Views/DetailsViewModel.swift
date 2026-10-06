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

    /// The marketing version and build the About row shows. Settable rather than an `init`
    /// parameter because `AppContainer` builds this model: the DEBUG fixture overrides it after
    /// construction so snapshots do not follow the build number.
    var appVersion: AppVersion = .main

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

    /// Observes the stream's initial Settings state and subsequent changes while Details is shown.
    func observeLiveActivityPermission() async {
        let updates = liveActivityPermission.enablementUpdates()
        refreshLiveActivityPermission()
        for await enabled in updates {
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
        Self.versionBuildText(version: appVersion.version, build: appVersion.build)
    }

    nonisolated static func versionBuildText(version: String, build: String) -> String {
        String(format: String(localized: "about.version_build %@ %@"), version, build)
    }
}

extension DetailsViewModel {
    struct AppVersion: Equatable {
        let version: String
        let build: String

        /// The running app's own values; "—" stands in for a key the bundle lacks.
        static var main: AppVersion {
            let info = Bundle.main.infoDictionary
            return AppVersion(
                version: info?["CFBundleShortVersionString"] as? String ?? "—",
                build: info?["CFBundleVersion"] as? String ?? "—"
            )
        }
    }
}
