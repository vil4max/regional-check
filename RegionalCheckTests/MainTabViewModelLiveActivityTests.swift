import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@Suite(.timeLimit(.minutes(1)), .removesDefaultsSuites)
@MainActor
struct MainTabViewModelLiveActivityTests {
    @Test("REQ-REFRESH-006 a newer check during a standing alarm reaches the phone's Live Activity")
    func samePhaseCheckReachesActivity() async throws {
        let harness = PhoneActivityHarness(cachedPhase: .alarm)
        harness.appear()
        defer { harness.viewModel.disappear() }
        await harness.poll(.alarm)
        let firstDate = harness.clock.now
        let receivedFirst = await eventually { harness.host.lastShown?.checkedAt == firstDate }
        try #require(receivedFirst)

        harness.clock.advancePastFetchFloor()
        await harness.poll(.alarm)

        let receivedNewCheck = await eventually { harness.host.lastShown?.checkedAt == harness.clock.now }
        #expect(receivedNewCheck)
        #expect(harness.host.lastShown?.phase == .alarm)
        #expect(harness.host.lastShown?.isStale == false)
        #expect(await harness.provider.requestCount == 2)
    }

    @Test("REQ-REFRESH-006 a failed scheduled poll marks a fresh phone activity stale")
    func failedPollMarksActivityStale() async throws {
        let harness = PhoneActivityHarness(cachedPhase: .alarm)
        harness.appear()
        defer { harness.viewModel.disappear() }
        await harness.activity.settle()
        try #require(harness.host.lastShown?.isStale == false)
        let checkedAt = harness.host.lastShown?.checkedAt

        await harness.provider.enqueue(.failure(URLError(.notConnectedToInternet)))
        await harness.status.refresh(isScheduled: true)

        let receivedFailure = await eventually { harness.host.lastShown?.isStale == true }
        #expect(receivedFailure)
        #expect(harness.host.lastShown?.phase == .alarm)
        #expect(harness.host.lastShown?.checkedAt == checkedAt)
        #expect(await harness.provider.requestCount == 1)
    }

    @Test("REQ-SURF-009 a phone phase change still reaches the Live Activity")
    func changedPhaseReachesActivity() async {
        let harness = PhoneActivityHarness(cachedPhase: .quiet)
        harness.appear()
        defer { harness.viewModel.disappear() }

        await harness.poll(.alarm)

        let receivedAlarm = await eventually { harness.host.lastShown?.phase == .alarm }
        #expect(receivedAlarm)
    }

    @Test("Repeated appearance arms only one Live Activity content observer")
    func repeatedAppearanceDoesNotDuplicateObservation() async {
        let queue = ScheduledChangeQueue()
        let harness = PhoneActivityHarness(cachedPhase: .quiet, queue: queue)
        harness.appear()
        harness.appear()
        defer { harness.viewModel.disappear() }
        let initialUpdates = harness.syncs.count

        await harness.poll(.alarm)
        queue.drain()

        #expect(harness.syncs.count == initialUpdates + 1)
        await harness.activity.settle()
        #expect(harness.host.lastShown?.phase == .alarm)
    }

    @Test("Disappearance discards an already queued Live Activity content change")
    func disappearanceStopsQueuedUpdates() async throws {
        let queue = ScheduledChangeQueue()
        let harness = PhoneActivityHarness(cachedPhase: .quiet, queue: queue)
        harness.appear()
        let initialUpdates = harness.syncs.count
        await harness.poll(.alarm)
        try #require(queue.count == 1)

        harness.viewModel.disappear()
        queue.drain()

        #expect(harness.syncs.count == initialUpdates)
        harness.clock.advancePastFetchFloor()
        await harness.poll(.quiet)
        queue.drain()
        #expect(harness.syncs.count == initialUpdates)
    }

    @Test("A previous appearance cannot re-arm after the next appearance starts")
    func reappearanceRejectsOldObservationGeneration() async throws {
        let queue = ScheduledChangeQueue()
        let harness = PhoneActivityHarness(cachedPhase: .quiet, queue: queue)
        harness.appear()
        await harness.poll(.alarm)
        try #require(queue.count == 1)
        harness.viewModel.disappear()
        harness.appear()
        defer { harness.viewModel.disappear() }
        let initialUpdates = harness.syncs.count

        queue.drain()
        #expect(harness.syncs.count == initialUpdates)
        harness.clock.advancePastFetchFloor()
        await harness.poll(.quiet)
        queue.drain()
        #expect(harness.syncs.count == initialUpdates + 1)
    }
}

@MainActor
private final class PhoneActivityHarness {
    let clock = TestClock()
    let provider = PhoneStatusProvider()
    let host = FixtureLiveActivityHost()
    let syncs = SyncCounter()
    let activity: LiveActivityController
    let status: StatusController
    let viewModel: MainTabViewModel

    init(cachedPhase: AlertStatus, queue: ScheduledChangeQueue? = nil) {
        let fixture = AppContainer.fixture(defaultsSuite: TestDefaults.fixtureSuite("phone-activity"))
        let cached = Self.snapshot(cachedPhase, at: clock.now)
        status = StatusController(
            region: .kyivCity,
            provider: provider,
            environmentProvider: FixtureRefreshEnvironment(),
            persistence: PhoneSnapshotStore(snapshot: cached),
            widgetReloader: TestWidgetReloader(),
            now: { [clock] in clock.now }
        )
        activity = LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: true),
            liveActivityPermission: SilentAllowedPermission(),
            host: host
        )
        let sync = { [status, activity, syncs] in
            syncs.count += 1
            activity.syncContent(from: status)
        }
        if let queue {
            viewModel = MainTabViewModel(
                status: status,
                location: fixture.location,
                regions: fixture.regions,
                liveActivityPreference: fixture.liveActivityPreference,
                liveActivity: activity,
                syncLiveActivityContent: sync,
                scheduleContentChange: { change in queue.enqueue(change) }
            )
        } else {
            viewModel = MainTabViewModel(
                status: status,
                location: fixture.location,
                regions: fixture.regions,
                liveActivityPreference: fixture.liveActivityPreference,
                liveActivity: activity,
                syncLiveActivityContent: sync
            )
        }
    }

    func appear() {
        viewModel.appear(isOnboardingFinished: false)
        // Tests drive scheduled refreshes explicitly, without racing the timer loop.
        status.endPeriodicRefresh()
    }

    func poll(_ phase: AlertStatus) async {
        await provider.enqueue(.success(Self.snapshot(phase, at: clock.now)))
        await status.refresh(isScheduled: true)
    }

    private static func snapshot(_ phase: AlertStatus, at date: Date) -> AlertsSnapshot {
        AlertsSnapshot(source: "test", serverCachedAt: date, fetchedAt: date, statuses: [.kyivCity: phase])
    }
}

private actor PhoneStatusProvider: StatusProviding {
    private var results: [Result<AlertsSnapshot, URLError>] = []
    private(set) var requestCount = 0

    func enqueue(_ result: Result<AlertsSnapshot, URLError>) {
        results.append(result)
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        requestCount += 1
        guard !results.isEmpty else { throw URLError(.resourceUnavailable) }
        return try results.removeFirst().get()
    }
}

@MainActor
private final class PhoneSnapshotStore: StatusPersisting {
    private var snapshot: AlertsSnapshot

    init(snapshot: AlertsSnapshot) { self.snapshot = snapshot }
    func saveSnapshot(_ snapshot: AlertsSnapshot) { self.snapshot = snapshot }
    func loadSnapshot() -> AlertsSnapshot? { snapshot }
}

/// How often the view model pushed content, whatever the controller then did with it.
@MainActor
private final class SyncCounter {
    var count = 0
}

extension FixtureLiveActivityHost {
    /// The content ActivityKit was last given for a running activity.
    fileprivate var lastShown: DriveCheckActivityAttributes.ContentState? {
        for call in calls.reversed() {
            switch call {
            case .request(_, let state, _), .update(_, let state, _):
                return state
            case .end:
                return nil
            }
        }
        return nil
    }
}
