import DriveCheckKit
import Foundation

@MainActor
protocol StatusSessionManaging: AnyObject {
    func setRegion(_ region: AlertRegion)
    func beginPeriodicRefresh()
    func endPeriodicRefresh()
}

@MainActor
protocol LocationSessionManaging: AnyObject {
    var lastFix: LocationFix? { get }
    func beginUpdating()
    func endUpdating()
    func refreshAuthorization()
}

extension LocationSessionManaging {
    func refreshAuthorization() {}
}

@MainActor
protocol RegionSessionManaging: AnyObject {
    var selectedRegion: AlertRegion { get }
    func updateFromLocation(fix: LocationFix)
}

extension StatusController: StatusSessionManaging {}
extension LocationManager: LocationSessionManaging {}
extension RegionSelection: RegionSessionManaging {}

@MainActor
final class MainTabViewModel {
    private let status: any StatusSessionManaging
    private let location: any LocationSessionManaging
    private let regions: any RegionSessionManaging
    private let subscription: any SubscriptionManaging
    private let liveActivity: any LiveActivityControlling
    private let syncLiveActivityContent: () -> Void
    private var hasLocationClient = false

    init(
        status: any StatusSessionManaging,
        location: any LocationSessionManaging,
        regions: any RegionSessionManaging,
        subscription: any SubscriptionManaging,
        liveActivity: any LiveActivityControlling,
        syncLiveActivityContent: @escaping () -> Void
    ) {
        self.status = status
        self.location = location
        self.regions = regions
        self.subscription = subscription
        self.liveActivity = liveActivity
        self.syncLiveActivityContent = syncLiveActivityContent
    }

    /// `isOnboardingFinished == false` holds location back: `beginUpdating()` is what raises the
    /// system permission prompt, and on a first launch it appeared over the onboarding cover,
    /// before the app had said what it uses location for. Everything else starts at once — the
    /// first status fetch is the one the driver waits for, and Kyiv is a valid region to show.
    func appear(isOnboardingFinished: Bool = true) {
        if isOnboardingFinished {
            beginLocationIfNeeded()
        }
        status.setRegion(regions.selectedRegion)
        status.beginPeriodicRefresh()
        liveActivity.beginPhoneForegroundSession()
        syncLiveActivityContent()
    }

    func onboardingFinished() {
        beginLocationIfNeeded()
    }

    func disappear() {
        status.endPeriodicRefresh()
        // Location clients are reference counted; only give back the one this session took.
        if hasLocationClient {
            hasLocationClient = false
            location.endUpdating()
        }
    }

    private func beginLocationIfNeeded() {
        guard !hasLocationClient else { return }
        hasLocationClient = true
        location.beginUpdating()
    }

    func regionChanged(_ region: AlertRegion) {
        status.setRegion(region)
        syncLiveActivityContent()
    }

    func locationChanged() {
        guard let fix = location.lastFix else { return }
        regions.updateFromLocation(fix: fix)
    }

    func liveActivityContentChanged() {
        syncLiveActivityContent()
    }

    func setLiveActivityEnabled(_ enabled: Bool) {
        subscription.setLiveActivityEnabled(enabled)
        if enabled {
            liveActivity.beginPhoneForegroundSession()
            syncLiveActivityContent()
        } else {
            liveActivity.endAll()
        }
    }
}
