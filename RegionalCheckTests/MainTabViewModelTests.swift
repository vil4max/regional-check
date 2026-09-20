import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct MainTabViewModelTests {
    @Test
    func appearStartsPhoneSessionInExistingOrder() {
        let harness = Harness()

        harness.viewModel.appear()

        #expect(harness.events.values == [
            .locationStarted,
            .regionSet(.kyivCity),
            .refreshStarted,
            .phoneSessionStarted,
            .contentSynced
        ])
    }

    @Test
    func disappearStopsRefreshBeforeLocation() {
        let harness = Harness()

        harness.viewModel.disappear()

        #expect(harness.events.values == [.refreshStopped, .locationStopped])
    }

    @Test
    func regionChangeUpdatesStatusBeforeSync() {
        let harness = Harness()

        harness.viewModel.regionChanged(.lviv)

        #expect(harness.events.values == [.regionSet(.lviv), .contentSynced])
    }

    @Test
    func locationChangeForwardsLatestFix() {
        let fix = LocationFix(
            coordinate: .init(latitude: 50, longitude: 36),
            horizontalAccuracy: 40,
            timestamp: Date()
        )
        let harness = Harness(lastFix: fix)

        harness.viewModel.locationChanged()

        #expect(harness.regions.receivedFix == fix)
    }

    @Test
    func locationChangeWithoutFixDoesNothing() {
        let harness = Harness(lastFix: nil)

        harness.viewModel.locationChanged()

        #expect(harness.regions.receivedFix == nil)
    }

    @Test
    func disablingLiveActivityEndsAllSessionsWithoutSync() {
        let harness = Harness()

        harness.viewModel.setLiveActivityEnabled(false)

        #expect(harness.events.values == [.liveActivityEnabled(false), .allSessionsEnded])
    }

    @Test
    func enablingLiveActivityStartsPhoneSessionAndSyncs() {
        let harness = Harness()

        harness.viewModel.setLiveActivityEnabled(true)

        #expect(harness.events.values == [
            .liveActivityEnabled(true),
            .phoneSessionStarted,
            .contentSynced
        ])
    }
}

@MainActor
private final class Harness {
    let events = EventRecorder()
    let regions: RegionSessionSpy
    let viewModel: MainTabViewModel

    init(lastFix: LocationFix? = nil) {
        let status = StatusSessionSpy(events: events)
        let location = LocationSessionSpy(lastFix: lastFix, events: events)
        let regions = RegionSessionSpy(events: events)
        let subscription = SubscriptionSessionSpy(events: events)
        let liveActivity = LiveActivitySessionSpy(events: events)
        self.regions = regions
        viewModel = MainTabViewModel(
            status: status,
            location: location,
            regions: regions,
            subscription: subscription,
            liveActivity: liveActivity,
            syncLiveActivityContent: { [events] in events.values.append(.contentSynced) }
        )
    }
}

@MainActor
private final class EventRecorder {
    var values: [SessionEvent] = []
}

private enum SessionEvent: Equatable {
    case locationStarted
    case locationStopped
    case regionSet(AlertRegion)
    case refreshStarted
    case refreshStopped
    case phoneSessionStarted
    case allSessionsEnded
    case liveActivityEnabled(Bool)
    case contentSynced
}

@MainActor
private final class StatusSessionSpy: StatusSessionManaging {
    private let events: EventRecorder

    init(events: EventRecorder) {
        self.events = events
    }

    func setRegion(_ region: AlertRegion) {
        events.values.append(.regionSet(region))
    }

    func beginPeriodicRefresh() {
        events.values.append(.refreshStarted)
    }

    func endPeriodicRefresh() {
        events.values.append(.refreshStopped)
    }
}

@MainActor
private final class LocationSessionSpy: LocationSessionManaging {
    let lastFix: LocationFix?
    private let events: EventRecorder

    init(lastFix: LocationFix?, events: EventRecorder) {
        self.lastFix = lastFix
        self.events = events
    }

    func beginUpdating() {
        events.values.append(.locationStarted)
    }

    func endUpdating() {
        events.values.append(.locationStopped)
    }
}

@MainActor
private final class RegionSessionSpy: RegionSessionManaging {
    let selectedRegion = AlertRegion.kyivCity
    private let events: EventRecorder
    private(set) var receivedFix: LocationFix?

    init(events: EventRecorder) {
        self.events = events
    }

    func updateFromLocation(fix: LocationFix) {
        receivedFix = fix
    }
}

@MainActor
private final class SubscriptionSessionSpy: SubscriptionManaging {
    var state = SubscriptionState()
    var isPro = false
    private let events: EventRecorder

    init(events: EventRecorder) {
        self.events = events
    }

    func start() async {}
    func refreshProducts() async {}
    func purchase(productID _: String) async -> PurchaseResult {
        .cancelled
    }

    func restore() async -> RestoreOutcome {
        .empty
    }

    func allows(_: PremiumFeature) -> Bool {
        false
    }

    func setLiveActivityEnabled(_ enabled: Bool) {
        events.values.append(.liveActivityEnabled(enabled))
    }

    func entitlementChanges() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

@MainActor
private final class LiveActivitySessionSpy: LiveActivityControlling {
    private let events: EventRecorder

    init(events: EventRecorder) {
        self.events = events
    }

    func beginPhoneForegroundSession() {
        events.values.append(.phoneSessionStarted)
    }

    func endPhoneForegroundSession() {}
    func beginCarPlaySession() {}
    func endCarPlaySession() {}
    func update(
        phase _: DriveCheckActivityPhase,
        regionTitle _: String,
        checkedAt _: Date?,
        sourceLabel _: String,
        isStale _: Bool
    ) {}

    func endAll() {
        events.values.append(.allSessionsEnded)
    }
}
