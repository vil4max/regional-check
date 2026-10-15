import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

/// REQ-SURF-009: the Live Activity's Refresh button, as the app performs it. The process owns no
/// activity yet: the one on screen is a survivor, as when iOS launches the app only for the intent.
/// Assertions follow `refreshLiveActivity()` directly, because iOS may suspend the app once it returns.
@MainActor
struct LiveActivityRefresherTests {
    private static let now = Date(timeIntervalSince1970: 1_789_555_260)

    private let host = FixtureLiveActivityHost()

    @Test("REQ-SURF-009 Refresh after the all-clear ends the activity before the intent returns")
    func allClearReachesTheActivity() async {
        let provider = CountingStatusProvider(result: .success(snapshot(.quiet, checkedAt: Self.now)))
        let refresher = makeRefresher(cached: snapshot(.alarm, checkedAt: Self.now - 3600), provider: provider)

        await refresher.refreshLiveActivity()

        #expect(host.calls == [.end(id: 1, state: nil, dismissal: .immediate)])
    }

    @Test("REQ-SURF-009 a failed Refresh keeps the alarm and marks it stale")
    func failureKeepsTheAlarmStale() async {
        let provider = CountingStatusProvider(result: .failure(URLError(.notConnectedToInternet)))
        let refresher = makeRefresher(cached: snapshot(.alarm, checkedAt: Self.now - 3600), provider: provider)

        await refresher.refreshLiveActivity()

        #expect(shownUpdates().last == ShownUpdate(phase: .alarm, isStale: true))
    }

    @Test("REQ-PROVIDER-002 a second Refresh inside the fetch floor sends no request")
    func floorHoldsARepeatedTap() async {
        let provider = CountingStatusProvider(result: .success(snapshot(.alarm, checkedAt: Self.now)))
        let refresher = makeRefresher(cached: nil, provider: provider)

        await refresher.refreshLiveActivity()
        await refresher.refreshLiveActivity()

        #expect(provider.requestCount == 1)
        let fresh = ShownUpdate(phase: .alarm, isStale: false)
        #expect(shownUpdates() == [fresh, fresh])
    }

    @Test("REQ-SURF-009 a fetch that outlasts the intent's budget still updates the activity from the cache")
    func slowFetchStillUpdatesWithinBudget() async {
        let provider = HangingStatusProvider()
        let refresher = makeRefresher(
            cached: snapshot(.alarm, checkedAt: Self.now - 3600),
            provider: provider,
            sleeping: ImmediateSleeping()
        )

        await refresher.refreshLiveActivity()

        #expect(shownUpdates().last == ShownUpdate(phase: .alarm, isStale: true))
    }

    private func makeRefresher(
        cached: AlertsSnapshot?,
        provider: any StatusProviding,
        sleeping: any BoundedAwait.Sleeping = BoundedAwait.ContinuousSleeping()
    ) -> LiveActivityRefresher {
        let status = StatusController(
            region: .kyivCity,
            provider: provider,
            environmentProvider: FixtureRefreshEnvironment(),
            persistence: SnapshotStore(snapshot: cached),
            widgetReloader: TestWidgetReloader(),
            now: { Self.now }
        )
        host.addSurvivor()
        let liveActivity = LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: true),
            liveActivityPermission: SilentAllowedPermission(),
            host: host
        )
        return LiveActivityRefresher(
            status: status,
            liveActivity: liveActivity,
            syncLiveActivityContent: { liveActivity.syncContent(from: status) },
            sleeping: sleeping
        )
    }

    private func shownUpdates() -> [ShownUpdate] {
        host.calls.compactMap { call in
            guard case .update(_, let state, _) = call else { return nil }
            return ShownUpdate(phase: state.phase, isStale: state.isStale)
        }
    }

    private func snapshot(_ status: AlertStatus, checkedAt: Date) -> AlertsSnapshot {
        AlertsSnapshot(source: "test", serverCachedAt: checkedAt, fetchedAt: checkedAt, statuses: [.kyivCity: status])
    }
}

private struct ShownUpdate: Equatable {
    let phase: DriveCheckActivityPhase
    let isStale: Bool
}

private final class CountingStatusProvider: StatusProviding {
    private let result: Result<AlertsSnapshot, any Error>
    private let requests = Mutex(0)
    var requestCount: Int { requests.withLock { $0 } }

    init(result: Result<AlertsSnapshot, any Error>) {
        self.result = result
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        requests.withLock { $0 += 1 }
        return try result.get()
    }
}

@MainActor
private final class SnapshotStore: StatusPersisting {
    private var snapshot: AlertsSnapshot?

    init(snapshot: AlertsSnapshot?) {
        self.snapshot = snapshot
    }

    func saveSnapshot(_ snapshot: AlertsSnapshot) {
        self.snapshot = snapshot
    }

    func loadSnapshot() -> AlertsSnapshot? {
        snapshot
    }
}

/// Never answers, the way a request on a dead network waits for its timeout.
private struct HangingStatusProvider: StatusProviding {
    func fetchAlerts() async throws -> AlertsSnapshot {
        try await Task.sleep(for: .seconds(3600))
        throw CancellationError()
    }
}

private struct ImmediateSleeping: BoundedAwait.Sleeping {
    func sleep(for _: Duration) async throws {}
}
