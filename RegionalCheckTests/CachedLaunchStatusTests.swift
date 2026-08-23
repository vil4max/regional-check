import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct CachedLaunchStatusTests {

    // MARK: - Doubles

    private final class CacheStore: StatusPersisting, @unchecked Sendable {
        var snapshot: AlertsSnapshot?
        let events: PersistenceRecorder

        init(events: PersistenceRecorder) {
            self.events = events
        }

        func saveRegion(_: AlertRegion) {}

        func saveSnapshot(_ snapshot: AlertsSnapshot) {
            self.snapshot = snapshot
            events.record(.snapshotSaved)
        }

        func loadSnapshot() -> AlertsSnapshot? {
            snapshot
        }
    }

    private final class WidgetReloader: WidgetReloading, @unchecked Sendable {
        let events: PersistenceRecorder

        init(events: PersistenceRecorder) {
            self.events = events
        }

        func reloadAllTimelines() {
            events.record(.widgetsReloaded)
        }
    }

    private enum Event: Equatable {
        case snapshotSaved
        case widgetsReloaded
    }

    @MainActor
    private final class PersistenceRecorder: @unchecked Sendable {
        private(set) var values: [Event] = []

        func record(_ event: Event) {
            values.append(event)
        }
    }

    // MARK: - Helpers

    private enum FixedClock {
        static let now = Date(timeIntervalSince1970: 10000)
    }

    private func makeController(
        cache: CacheStore,
        provider: any StatusProviding,
        region: AlertRegion = .kyivCity,
        now: @escaping () -> Date = { FixedClock.now }
    ) -> StatusController {
        StatusController(
            region: region,
            provider: provider,
            persistence: cache,
            widgetReloader: WidgetReloader(events: cache.events),
            now: now
        )
    }

    private func cachedSnapshot(
        region: AlertRegion = .kyivCity,
        checkedAt: Date
    ) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "cache",
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: [region: .quiet]
        )
    }

    // MARK: - Scenarios

    @Test
    func noCachedSnapshotKeepsInitialIdleState() {
        let cache = CacheStore(events: PersistenceRecorder())
        let controller = makeController(
            cache: cache,
            provider: MockStatusProvider(error: URLError(.notConnectedToInternet))
        )

        #expect(controller.state == .idle)
    }

    @Test
    func freshCachedSnapshotIsAvailableImmediately() {
        let cache = CacheStore(events: PersistenceRecorder())
        cache.snapshot = cachedSnapshot(checkedAt: FixedClock.now.addingTimeInterval(-60))
        let controller = makeController(
            cache: cache,
            provider: MockStatusProvider(error: URLError(.notConnectedToInternet))
        )

        #expect(controller.state == .quiet(lastCheckedAt: cache.snapshot?.checkedAt ?? .distantPast))
        #expect(controller.state.phase == .quiet)
        #expect(!controller.isDataStale)
    }

    @Test
    func staleCachedSnapshotIsAvailableAndReportedStale() {
        let cache = CacheStore(events: PersistenceRecorder())
        cache.snapshot = cachedSnapshot(checkedAt: FixedClock.now.addingTimeInterval(-10000))
        let controller = makeController(
            cache: cache,
            provider: MockStatusProvider(error: URLError(.notConnectedToInternet))
        )

        #expect(controller.state.phase == .quiet)
        #expect(controller.isDataStale)
    }

    @Test
    func networkSuccessReplacesCachedState() async {
        let cache = CacheStore(events: PersistenceRecorder())
        cache.snapshot = cachedSnapshot(checkedAt: FixedClock.now.addingTimeInterval(-3600))
        let networkSnapshot = TestFixtures.quietSnapshot(region: .lviv, checkedAt: FixedClock.now)
        let controller = makeController(
            cache: cache,
            provider: MockStatusProvider(snapshot: networkSnapshot),
            region: .lviv
        )

        await controller.refresh()

        #expect(controller.lastSnapshot == networkSnapshot)
        #expect(controller.state.phase == .quiet)
        #expect(controller.state.checkedAt == FixedClock.now)
        #expect(!controller.isDataStale)
    }

    @Test
    func networkFailureWithCacheRetainsCachedStatus() async {
        let cache = CacheStore(events: PersistenceRecorder())
        let cachedCheckedAt = FixedClock.now.addingTimeInterval(-120)
        cache.snapshot = cachedSnapshot(checkedAt: cachedCheckedAt)
        let controller = makeController(
            cache: cache,
            provider: MockStatusProvider(error: URLError(.notConnectedToInternet))
        )

        await controller.refresh()

        #expect(controller.state == .quiet(lastCheckedAt: cachedCheckedAt))
        #expect(controller.state.phase != StatusState.Phase.error)
    }

    @Test
    func networkFailureWithoutCacheShowsError() async {
        let cache = CacheStore(events: PersistenceRecorder())
        let controller = makeController(cache: cache, provider: MockStatusProvider(error: URLError(.timedOut)))

        await controller.refresh()

        #expect(controller.state == .error)
    }

    @Test
    func cachedSnapshotWithoutSelectedRegionResolvesRegionUnavailable() {
        let cache = CacheStore(events: PersistenceRecorder())
        cache.snapshot = cachedSnapshot(region: .kharkiv, checkedAt: FixedClock.now)
        let controller = makeController(
            cache: cache,
            provider: MockStatusProvider(error: URLError(.timedOut)),
            region: .kyivCity
        )

        #expect(controller.state == .regionUnavailable)
    }

    @Test
    func successfulRefreshPersistsBeforeWidgetReload() async {
        let recorder = PersistenceRecorder()
        let cache = CacheStore(events: recorder)
        cache.snapshot = cachedSnapshot(checkedAt: FixedClock.now.addingTimeInterval(-3600))
        let controller = makeController(
            cache: cache,
            provider: MockStatusProvider(snapshot: TestFixtures.quietSnapshot())
        )

        await controller.refresh()

        #expect(recorder.values == [.snapshotSaved, .widgetsReloaded])
    }

    @Test
    func regionChangeResolvesLatestSnapshotAndRefreshes() {
        let cache = CacheStore(events: PersistenceRecorder())
        let checkedAt = FixedClock.now.addingTimeInterval(-30)
        let snapshot = AlertsSnapshot(
            source: "cache",
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: [.kyivCity: .quiet, .lviv: .alarm]
        )
        cache.snapshot = snapshot
        let controller = makeController(cache: cache, provider: MockStatusProvider(snapshot: snapshot))

        controller.setRegion(.lviv)

        #expect(controller.currentRegion == .lviv)
        #expect(controller.regionTitle == AlertRegion.lviv.title)
        #expect(controller.state == .alarm(lastCheckedAt: checkedAt))
    }
}
