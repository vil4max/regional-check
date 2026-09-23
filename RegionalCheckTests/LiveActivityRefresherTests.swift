import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// REQ-SURF-009: the Live Activity's Refresh button, as the app performs it.
@MainActor
struct LiveActivityRefresherTests {
    private static let now = Date(timeIntervalSince1970: 1_789_555_260)

    @Test("REQ-SURF-009 Refresh after the all-clear hands the activity a fresh quiet phase")
    func allClearReachesTheActivity() async {
        let provider = CountingStatusProvider(result: .success(snapshot(.quiet, checkedAt: Self.now)))
        let (refresher, spy) = makeRefresher(cached: snapshot(.alarm, checkedAt: Self.now - 3600), provider: provider)

        await refresher.refreshLiveActivity()

        #expect(spy.updates.last == ActivityUpdate(phase: .quiet, isStale: false))
        #expect(spy.settleCount == 1)
    }

    @Test("REQ-SURF-009 a failed Refresh keeps the alarm and marks it stale")
    func failureKeepsTheAlarmStale() async {
        let provider = CountingStatusProvider(result: .failure(URLError(.notConnectedToInternet)))
        let (refresher, spy) = makeRefresher(cached: snapshot(.alarm, checkedAt: Self.now - 3600), provider: provider)

        await refresher.refreshLiveActivity()

        #expect(spy.updates.last == ActivityUpdate(phase: .alarm, isStale: true))
    }

    @Test("REQ-PROVIDER-002 a second Refresh inside the fetch floor sends no request")
    func floorHoldsARepeatedTap() async {
        let provider = CountingStatusProvider(result: .success(snapshot(.alarm, checkedAt: Self.now)))
        let (refresher, spy) = makeRefresher(cached: nil, provider: provider)

        await refresher.refreshLiveActivity()
        await refresher.refreshLiveActivity()

        #expect(provider.requestCount == 1)
        #expect(spy.updates.count == 2)
        #expect(spy.updates.last == ActivityUpdate(phase: .alarm, isStale: false))
    }

    private func makeRefresher(
        cached: AlertsSnapshot?,
        provider: CountingStatusProvider
    ) -> (LiveActivityRefresher, LiveActivityUpdateSpy) {
        let status = StatusController(
            region: .kyivCity,
            provider: provider,
            persistence: SnapshotStore(snapshot: cached),
            widgetReloader: TestWidgetReloader(),
            now: { Self.now }
        )
        let spy = LiveActivityUpdateSpy()
        return (LiveActivityRefresher(status: status, liveActivity: spy), spy)
    }

    private func snapshot(_ status: AlertStatus, checkedAt: Date) -> AlertsSnapshot {
        AlertsSnapshot(source: "test", serverCachedAt: checkedAt, fetchedAt: checkedAt, statuses: [.kyivCity: status])
    }
}

private struct ActivityUpdate: Equatable {
    let phase: DriveCheckActivityPhase
    let isStale: Bool
}

@MainActor
private final class LiveActivityUpdateSpy: LiveActivityControlling {
    private(set) var updates: [ActivityUpdate] = []
    private(set) var settleCount = 0

    func beginPhoneForegroundSession() {}
    func endPhoneForegroundSession() {}
    func beginCarPlaySession() {}
    func endCarPlaySession() {}
    func endAll() {}

    func update(
        phase: DriveCheckActivityPhase,
        regionTitle _: String,
        checkedAt _: Date?,
        sourceLabel _: String,
        isStale: Bool
    ) {
        updates.append(ActivityUpdate(phase: phase, isStale: isStale))
    }

    func settle() async {
        settleCount += 1
    }
}

private final class CountingStatusProvider: StatusProviding, @unchecked Sendable {
    private let result: Result<AlertsSnapshot, any Error>
    private(set) var requestCount = 0

    init(result: Result<AlertsSnapshot, any Error>) {
        self.result = result
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        requestCount += 1
        return try result.get()
    }
}

private final class SnapshotStore: StatusPersisting, @unchecked Sendable {
    private var snapshot: AlertsSnapshot?

    init(snapshot: AlertsSnapshot?) {
        self.snapshot = snapshot
    }

    func saveRegion(_: AlertRegion) {}

    func saveSnapshot(_ snapshot: AlertsSnapshot) {
        self.snapshot = snapshot
    }

    func loadSnapshot() -> AlertsSnapshot? {
        snapshot
    }
}
