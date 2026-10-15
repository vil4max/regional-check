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

        #expect(
            harness.events.values == [
                .locationStarted,
                .refreshStarted,
                .contentSynced(inPhoneSession: true),
            ])
    }

    @Test("REQ-REGION-010 the location prompt waits until onboarding is finished")
    func appearDuringOnboardingStartsEverythingButLocation() {
        let harness = Harness()

        harness.viewModel.appear(isOnboardingFinished: false)

        // The status still loads at once: the first fetch is the one the driver waits for, and
        // Kyiv is a valid region to show behind the onboarding cover.
        #expect(
            harness.events.values == [
                .refreshStarted,
                .contentSynced(inPhoneSession: true),
            ])

        harness.viewModel.onboardingFinished()
        #expect(harness.events.values.last == .locationStarted)

        // Location clients are reference counted: finishing twice must not start a second one.
        harness.viewModel.onboardingFinished()
        #expect(harness.events.values.count(where: { $0 == .locationStarted }) == 1)
    }

    @Test("REQ-REGION-010 a session that never started location does not stop it either")
    func disappearAfterUnfinishedOnboardingLeavesLocationAlone() {
        let harness = Harness()

        harness.viewModel.appear(isOnboardingFinished: false)
        harness.viewModel.disappear()

        #expect(!harness.events.values.contains(.locationStopped))
    }

    @Test
    func disappearStopsRefreshBeforeLocation() {
        let harness = Harness()
        harness.viewModel.appear()
        harness.events.values.removeAll()

        harness.viewModel.disappear()

        #expect(harness.events.values == [.refreshStopped, .locationStopped])
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
    func disablingLiveActivityEndsActivityWithoutSync() async throws {
        let harness = Harness()
        harness.liveActivity.beginPhoneForegroundSession()
        harness.liveActivity.update(phase: .alarm, regionTitle: "Kyiv", checkedAt: nil, sourceLabel: "", isStale: false)
        await harness.liveActivity.settle()
        try #require(harness.host.runningActivities().count == 1)

        harness.viewModel.setLiveActivityEnabled(false)
        await harness.liveActivity.settle()

        #expect(harness.events.values == [.liveActivityEnabled(false)])
        #expect(harness.host.runningActivities().isEmpty)
        #expect(harness.liveActivity.clients == [.phoneForeground])
    }

    @Test
    func enablingLiveActivityStartsPhoneSessionAndSyncs() {
        let harness = Harness()

        harness.viewModel.setLiveActivityEnabled(true)

        #expect(
            harness.events.values == [
                .liveActivityEnabled(true),
                .contentSynced(inPhoneSession: true),
            ])
    }
}

@MainActor
private final class Harness {
    let events = EventRecorder()
    let regions: RegionSessionSpy
    let host = FixtureLiveActivityHost()
    let liveActivity: LiveActivityController
    let viewModel: MainTabViewModel

    init(lastFix: LocationFix? = nil) {
        let status = StatusSessionSpy(events: events)
        let location = LocationSessionSpy(lastFix: lastFix, events: events)
        let regions = RegionSessionSpy()
        let preference = PreferenceSessionSpy(events: events)
        let liveActivity = LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: true),
            liveActivityPermission: SilentAllowedPermission(),
            host: host
        )
        self.regions = regions
        self.liveActivity = liveActivity
        viewModel = MainTabViewModel(
            status: status,
            location: location,
            regions: regions,
            liveActivityPreference: preference,
            liveActivity: liveActivity,
            // Records whether the session was open when content arrived: only then can it start one.
            syncLiveActivityContent: { [events, liveActivity] in
                events.values.append(.contentSynced(inPhoneSession: liveActivity.clients.contains(.phoneForeground)))
            }
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
    case refreshStarted
    case refreshStopped
    case liveActivityEnabled(Bool)
    case contentSynced(inPhoneSession: Bool)
}

@MainActor
private final class StatusSessionSpy: StatusSessionManaging {
    private let events: EventRecorder

    init(events: EventRecorder) {
        self.events = events
    }

    func beginPeriodicRefresh() {
        events.values.append(.refreshStarted)
    }

    func endPeriodicRefresh() {
        events.values.append(.refreshStopped)
    }

    func trackLiveActivityContent() {}
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
    private(set) var receivedFix: LocationFix?

    func updateFromLocation(fix: LocationFix) {
        receivedFix = fix
    }
}

@MainActor
private final class PreferenceSessionSpy: LiveActivityPreferenceWriting {
    private let events: EventRecorder

    init(events: EventRecorder) {
        self.events = events
    }

    func setEnabled(_ enabled: Bool) {
        events.values.append(.liveActivityEnabled(enabled))
    }
}
