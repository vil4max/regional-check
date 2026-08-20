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

    func appear() {
        location.beginUpdating()
        status.setRegion(regions.selectedRegion)
        status.beginPeriodicRefresh()
        liveActivity.beginPhoneForegroundSession()
        syncLiveActivityContent()
    }

    func disappear() {
        status.endPeriodicRefresh()
        location.endUpdating()
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
