import DriveCheckKit
import Foundation
import Observation

@MainActor
protocol StatusSessionManaging: AnyObject {
    func setRegion(_ region: AlertRegion)
    func beginPeriodicRefresh()
    func endPeriodicRefresh()
    func trackLiveActivityContent()
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

extension StatusController: StatusSessionManaging {
    func trackLiveActivityContent() {
        _ = state
        _ = hasRefreshFailed
        _ = regionTitle
    }
}
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
    private let scheduleContentChange: @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void
    private var hasLocationClient = false
    private var contentObservationID: UUID?

    init(
        status: any StatusSessionManaging,
        location: any LocationSessionManaging,
        regions: any RegionSessionManaging,
        subscription: any SubscriptionManaging,
        liveActivity: any LiveActivityControlling,
        syncLiveActivityContent: @escaping () -> Void,
        scheduleContentChange: @escaping @Sendable (@escaping @MainActor @Sendable () -> Void) -> Void = { change in
            Task { @MainActor in change() }
        }
    ) {
        self.status = status
        self.location = location
        self.regions = regions
        self.subscription = subscription
        self.liveActivity = liveActivity
        self.syncLiveActivityContent = syncLiveActivityContent
        self.scheduleContentChange = scheduleContentChange
    }

    /// `isOnboardingFinished == false` holds location back: taking the first location client is
    /// what raises the system permission prompt, and on a first launch it appeared over the
    /// onboarding cover, before the app had said what it uses location for. This gate is only half
    /// of REQ-REGION-010 — `LocationManager` must also ask for nothing until a client exists, or
    /// CoreLocation's own authorization callback prompts from the container's construction.
    /// Everything else starts at once — the first status fetch is the one the driver waits for,
    /// and Kyiv is a valid region to show.
    func appear(isOnboardingFinished: Bool = true) {
        if isOnboardingFinished {
            beginLocationIfNeeded()
        }
        status.setRegion(regions.selectedRegion)
        status.beginPeriodicRefresh()
        liveActivity.beginPhoneForegroundSession()
        syncLiveActivityContent()
        if contentObservationID == nil {
            let id = UUID()
            contentObservationID = id
            observeLiveActivityContent(id: id)
        }
    }

    func onboardingFinished() {
        beginLocationIfNeeded()
    }

    func disappear() {
        contentObservationID = nil
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

    private func observeLiveActivityContent(id: UUID) {
        withObservationTracking {
            status.trackLiveActivityContent()
        } onChange: { @Sendable [weak self, scheduleContentChange] in
            // Observation fires before the write; enqueue the read and reject obsolete appearances.
            scheduleContentChange { [weak self] in
                guard let self, contentObservationID == id else { return }
                observeLiveActivityContent(id: id)
                syncLiveActivityContent()
            }
        }
    }
}
