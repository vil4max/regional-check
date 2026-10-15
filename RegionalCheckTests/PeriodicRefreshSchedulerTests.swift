import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

/// The running refresh loop, driven by a sleep the test releases by hand, so the cadence is
/// checked as the loop runs rather than only through `RefreshPolicy`'s arithmetic.
@MainActor
struct PeriodicRefreshSchedulerTests {
    @Test("REQ-REFRESH-002 the first sleep is the policy interval, followed by one scheduled refresh")
    func firstSleepThenOneRefresh() async throws {
        let harness = Harness()
        harness.controller.beginPeriodicRefresh()
        defer { harness.controller.endPeriodicRefresh() }

        try #require(await eventually { harness.sleep.requests.count == 1 })
        let policyInterval = RefreshPolicy.interval(for: harness.environment.quiet, jitterUnitInterval: 0.5)
        #expect(harness.sleep.requests == [policyInterval])
        #expect(policyInterval == .seconds(60))
        #expect(harness.controller.lastRefreshInterval == .seconds(60))
        #expect(harness.provider.fetchCount == 0)

        harness.sleep.wakeAll()
        try #require(await eventually { harness.sleep.requests.count == 2 })
        #expect(harness.provider.fetchCount == 1)
    }

    @Test("REQ-REFRESH-002 a Low Power Mode change restarts the loop with the new interval")
    func powerStateChangeRestartsWithNewInterval() async throws {
        let harness = Harness()
        harness.controller.beginPeriodicRefresh()
        defer { harness.controller.endPeriodicRefresh() }
        try #require(await eventually { harness.sleep.requests.count == 1 })

        harness.environment.isLowPowerModeEnabled = true
        harness.notifications.post(name: .NSProcessInfoPowerStateDidChange, object: nil)

        try #require(await eventually { harness.sleep.requests.count == 2 })
        #expect(harness.sleep.requests.last == .seconds(300))
        // The cancelled first sleep is gone; only the restarted one waits.
        try #require(await eventually { harness.sleep.pendingCount == 1 })
        #expect(harness.provider.fetchCount == 0)
    }

    @Test("REQ-REFRESH-002 the loop stops with its last client and ignores later power changes")
    func lastClientStopsTheLoop() async throws {
        let harness = Harness()
        harness.controller.beginPeriodicRefresh()
        harness.controller.beginPeriodicRefresh()
        try #require(await eventually { harness.sleep.requests.count == 1 })

        harness.controller.endPeriodicRefresh()
        #expect(harness.controller.isPeriodicRefreshRunning)
        #expect(harness.sleep.pendingCount == 1)

        harness.controller.endPeriodicRefresh()
        #expect(!harness.controller.isPeriodicRefreshRunning)
        try #require(await eventually { harness.sleep.pendingCount == 0 })

        harness.notifications.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
        // Lets a restart, if one were wrongly scheduled, reach the sleep before the assertion.
        _ = await eventually(timeout: .milliseconds(200)) { harness.sleep.requests.count > 1 }
        #expect(harness.sleep.requests.count == 1)
        #expect(harness.provider.fetchCount == 0)
    }
}

@MainActor
private struct Harness {
    let sleep = ManualSleep()
    let notifications = NotificationCenter()
    let environment = MutableRefreshEnvironment()
    let provider = CountingProvider()
    let controller: StatusController

    init() {
        controller = StatusController(
            region: .kyivCity,
            provider: provider,
            environmentProvider: environment,
            jitterUnitInterval: { 0.5 },
            periodicRefresh: PeriodicRefreshScheduler(sleep: sleep.sleep, notificationCenter: notifications)
        )
    }
}

/// A sleep that returns only when the test wakes it, or throws when its task is cancelled.
@MainActor
private final class ManualSleep {
    private(set) var requests: [Duration] = []
    private var waiters: [Int: CheckedContinuation<Void, any Error>] = [:]
    private var nextID = 0

    var pendingCount: Int {
        waiters.count
    }

    nonisolated var sleep: PeriodicRefreshScheduler.Sleep {
        { [self] duration in try await wait(duration) }
    }

    func wakeAll() {
        let pending = waiters.values
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    private func wait(_ duration: Duration) async throws {
        requests.append(duration)
        let id = nextID
        nextID += 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters[id] = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
            }
        }
    }
}

@MainActor
private final class MutableRefreshEnvironment: RefreshEnvironmentProviding {
    var isLowPowerModeEnabled = false

    var quiet: RefreshEnvironment {
        current(isAlarmActive: false)
    }

    func current(isAlarmActive: Bool) -> RefreshEnvironment {
        RefreshEnvironment(
            isAlarmActive: isAlarmActive,
            isLowPowerModeEnabled: isLowPowerModeEnabled,
            thermalState: .nominal,
            isExpensiveNetwork: false,
            isConstrainedNetwork: false
        )
    }
}

private final class CountingProvider: StatusProviding {
    private let count = Mutex(0)

    var fetchCount: Int {
        count.withLock { $0 }
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        count.withLock { $0 += 1 }
        return TestFixtures.quietSnapshot()
    }
}
