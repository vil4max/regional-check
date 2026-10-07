import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct MainTabViewModelLiveActivityTests {
    @Test("REQ-REFRESH-006 a newer check during a standing alarm reaches the phone's Live Activity")
    func samePhaseCheckReachesActivity() async throws {
        let harness = PhoneActivityHarness(cachedPhase: .alarm)
        harness.appear()
        defer { harness.viewModel.disappear() }
        await harness.poll(.alarm)
        let firstDate = harness.clock.now
        let receivedFirst = await eventually { harness.activity.updates.last?.checkedAt == firstDate }
        try #require(receivedFirst)

        harness.clock.advancePastFetchFloor()
        await harness.poll(.alarm)

        let receivedNewCheck = await eventually { harness.activity.updates.last?.checkedAt == harness.clock.now }
        #expect(receivedNewCheck)
        #expect(harness.activity.updates.last?.phase == .alarm)
        #expect(harness.activity.updates.last?.isStale == false)
        #expect(await harness.provider.requestCount == 2)
    }

    @Test("REQ-REFRESH-006 a failed scheduled poll marks a fresh phone activity stale")
    func failedPollMarksActivityStale() async throws {
        let harness = PhoneActivityHarness(cachedPhase: .alarm)
        harness.appear()
        defer { harness.viewModel.disappear() }
        try #require(harness.activity.updates.last?.isStale == false)
        let checkedAt = harness.activity.updates.last?.checkedAt

        await harness.provider.enqueue(.failure(URLError(.notConnectedToInternet)))
        await harness.status.refresh(isScheduled: true)

        let receivedFailure = await eventually { harness.activity.updates.last?.isStale == true }
        #expect(receivedFailure)
        #expect(harness.activity.updates.last?.phase == .alarm)
        #expect(harness.activity.updates.last?.checkedAt == checkedAt)
        #expect(await harness.provider.requestCount == 1)
    }

    @Test("REQ-SURF-009 a phone phase change still reaches the Live Activity")
    func changedPhaseReachesActivity() async {
        let harness = PhoneActivityHarness(cachedPhase: .quiet)
        harness.appear()
        defer { harness.viewModel.disappear() }

        await harness.poll(.alarm)

        let receivedAlarm = await eventually { harness.activity.updates.last?.phase == .alarm }
        #expect(receivedAlarm)
    }

    @Test("Repeated appearance arms only one Live Activity content observer")
    func repeatedAppearanceDoesNotDuplicateObservation() async {
        let queue = QueuedContentChanges()
        let harness = PhoneActivityHarness(cachedPhase: .quiet, queue: queue)
        harness.appear()
        harness.appear()
        defer { harness.viewModel.disappear() }
        let initialUpdates = harness.activity.updates.count

        await harness.poll(.alarm)
        queue.drain()

        #expect(harness.activity.updates.count == initialUpdates + 1)
        #expect(harness.activity.updates.last?.phase == .alarm)
    }

    @Test("Disappearance discards an already queued Live Activity content change")
    func disappearanceStopsQueuedUpdates() async throws {
        let queue = QueuedContentChanges()
        let harness = PhoneActivityHarness(cachedPhase: .quiet, queue: queue)
        harness.appear()
        let initialUpdates = harness.activity.updates.count
        await harness.poll(.alarm)
        try #require(queue.count == 1)

        harness.viewModel.disappear()
        queue.drain()

        #expect(harness.activity.updates.count == initialUpdates)
        harness.clock.advancePastFetchFloor()
        await harness.poll(.quiet)
        queue.drain()
        #expect(harness.activity.updates.count == initialUpdates)
    }

    @Test("A previous appearance cannot re-arm after the next appearance starts")
    func reappearanceRejectsOldObservationGeneration() async throws {
        let queue = QueuedContentChanges()
        let harness = PhoneActivityHarness(cachedPhase: .quiet, queue: queue)
        harness.appear()
        await harness.poll(.alarm)
        try #require(queue.count == 1)
        harness.viewModel.disappear()
        harness.appear()
        defer { harness.viewModel.disappear() }
        let initialUpdates = harness.activity.updates.count

        queue.drain()
        #expect(harness.activity.updates.count == initialUpdates)
        harness.clock.advancePastFetchFloor()
        await harness.poll(.quiet)
        queue.drain()
        #expect(harness.activity.updates.count == initialUpdates + 1)
    }

    private func eventually(_ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition(), ContinuousClock.now < deadline {
            await Task.yield()
        }
        return condition()
    }
}

@MainActor
private final class PhoneActivityHarness {
    let clock = TestClock()
    let provider = PhoneStatusProvider()
    let activity = PhoneActivitySpy()
    let status: StatusController
    let viewModel: MainTabViewModel

    init(cachedPhase: AlertStatus, queue: QueuedContentChanges? = nil) {
        let fixture = AppContainer.fixture(defaultsSuite: "PhoneActivityHarness.\(UUID().uuidString)")
        let cached = Self.snapshot(cachedPhase, at: clock.now)
        status = StatusController(
            region: .kyivCity,
            provider: provider,
            environmentProvider: FixtureRefreshEnvironment(),
            persistence: PhoneSnapshotStore(snapshot: cached),
            widgetReloader: TestWidgetReloader(),
            now: { [clock] in clock.now }
        )
        let sync = { [status, activity] in
            AppContainer.syncLiveActivityContent(status: status, liveActivity: activity)
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

private struct PhoneActivityUpdate: Equatable {
    let phase: DriveCheckActivityPhase
    let checkedAt: Date?
    let isStale: Bool
}

@MainActor
private final class PhoneActivitySpy: LiveActivityControlling {
    private(set) var updates: [PhoneActivityUpdate] = []

    func beginPhoneForegroundSession() {}
    func endPhoneForegroundSession() {}
    func beginCarPlaySession() {}
    func endCarPlaySession() {}
    func endAll() {}
    func settle() async {}

    func update(
        phase: DriveCheckActivityPhase,
        regionTitle _: String,
        checkedAt: Date?,
        sourceLabel _: String,
        isStale: Bool
    ) {
        updates.append(PhoneActivityUpdate(phase: phase, checkedAt: checkedAt, isStale: isStale))
    }
}

private final class QueuedContentChanges: Sendable {
    private let changes = Mutex<[@MainActor @Sendable () -> Void]>([])
    var count: Int { changes.withLock { $0.count } }

    func enqueue(_ change: @escaping @MainActor @Sendable () -> Void) {
        changes.withLock { $0.append(change) }
    }

    @MainActor
    func drain() {
        let pending = changes.withLock {
            let pending = $0
            $0.removeAll()
            return pending
        }
        for change in pending { change() }
    }
}
