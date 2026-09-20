import Foundation

/// The Details tab's own state (ADR 0015): what the settings rows show and where their actions
/// go. The summary above them keeps its own `StatusDetailsViewModel`.
@MainActor
@Observable
final class DetailsViewModel {
    private let location: any HomeLocationSource
    private let subscription: any SubscriptionManaging
    private let applyLiveActivityEnabled: (Bool) -> Void

    /// `setLiveActivityEnabled` is injected rather than sent to `subscription` directly: turning
    /// the switch also starts or ends the running activity, which `MainTabViewModel` owns.
    init(
        location: any HomeLocationSource,
        subscription: any SubscriptionManaging,
        setLiveActivityEnabled: @escaping (Bool) -> Void
    ) {
        self.location = location
        self.subscription = subscription
        applyLiveActivityEnabled = setLiveActivityEnabled
    }

    var isLocationAccessBlocked: Bool {
        location.isAuthorizationBlocked
    }

    var isLiveActivityEnabled: Bool {
        subscription.state.isLiveActivityEnabled
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
