import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct StatusControllerPersistenceTests {
    @Test
    func setRegionPersistsBeforeReloadingWidgets() {
        let events = PersistenceEvents()
        let controller = makeController(events: events)

        controller.setRegion(.lviv)

        #expect(events.values == [.regionSaved(.lviv), .widgetsReloaded])
    }

    @Test
    func refreshPersistsSnapshotBeforeReloadingWidgets() async {
        let events = PersistenceEvents()
        let snapshot = TestFixtures.quietSnapshot()
        let controller = makeController(events: events, snapshot: snapshot)

        await controller.refresh()

        #expect(events.values == [.snapshotSaved, .widgetsReloaded])
    }

    @Test
    func scheduledRefetchOfSameServerCacheDoesNotReloadWidgets() async {
        let events = PersistenceEvents()
        let cached = TestFixtures.quietSnapshot()
        let fetched = AlertsSnapshot(
            source: cached.source,
            serverCachedAt: cached.checkedAt,
            fetchedAt: cached.fetchedAt.addingTimeInterval(60),
            statuses: cached.statuses
        )
        let controller = makeController(events: events, snapshot: fetched, cached: cached)

        await controller.refresh(isScheduled: true)
        await controller.refresh(isScheduled: true)

        #expect(events.values == [.snapshotSaved, .snapshotSaved])
        #expect(controller.lastSnapshot == fetched)
    }

    @Test
    func manualRefreshReloadsWidgetsEvenWhenServerCacheIsUnchanged() async {
        let events = PersistenceEvents()
        let snapshot = TestFixtures.quietSnapshot()
        let controller = makeController(events: events, snapshot: snapshot, cached: snapshot)

        await controller.refresh()

        #expect(events.values == [.snapshotSaved, .widgetsReloaded])
    }

    @Test
    func scheduledRefreshWithNewSourceTimeReloadsWidgets() async {
        let events = PersistenceEvents()
        let controller = makeController(
            events: events,
            snapshot: TestFixtures.quietSnapshot(checkedAt: Date(timeIntervalSince1970: 61)),
            cached: TestFixtures.quietSnapshot()
        )

        await controller.refresh(isScheduled: true)

        #expect(events.values == [.snapshotSaved, .widgetsReloaded])
    }

    @Test
    func scheduledRefreshReloadsWhenOnlyAnotherRegionsStatusChanges() async {
        let events = PersistenceEvents()
        let cached = TestFixtures.quietSnapshot()
        let changed = AlertsSnapshot(
            source: cached.source,
            serverCachedAt: cached.checkedAt,
            fetchedAt: cached.fetchedAt,
            statuses: [.kyivCity: .quiet, .lviv: .alarm]
        )
        let controller = makeController(events: events, snapshot: changed, cached: cached)

        await controller.refresh(isScheduled: true)

        #expect(events.values == [.snapshotSaved, .widgetsReloaded])
    }

    @Test
    func scheduledRefreshReloadsWhenSourceLabelChanges() async {
        let events = PersistenceEvents()
        let cached = TestFixtures.quietSnapshot()
        let changed = AlertsSnapshot(
            source: "another feed",
            serverCachedAt: cached.checkedAt,
            fetchedAt: cached.fetchedAt,
            statuses: cached.statuses
        )
        let controller = makeController(events: events, snapshot: changed, cached: cached)

        await controller.refresh(isScheduled: true)

        #expect(events.values == [.snapshotSaved, .widgetsReloaded])
    }

    private func makeController(
        events: PersistenceEvents,
        snapshot: AlertsSnapshot = TestFixtures.quietSnapshot(),
        cached: AlertsSnapshot? = nil
    ) -> StatusController {
        StatusController(
            region: .kyivCity,
            provider: MockStatusProvider(snapshot: snapshot),
            persistence: StatusPersistenceSpy(events: events, snapshot: cached),
            widgetReloader: StatusWidgetReloaderSpy(events: events)
        )
    }
}

@MainActor
private final class PersistenceEvents {
    var values: [PersistenceEvent] = []
}

private enum PersistenceEvent: Equatable {
    case regionSaved(AlertRegion)
    case snapshotSaved
    case widgetsReloaded
}

@MainActor
private final class StatusPersistenceSpy: StatusPersisting {
    private let events: PersistenceEvents
    private var snapshot: AlertsSnapshot?

    init(events: PersistenceEvents, snapshot: AlertsSnapshot?) {
        self.events = events
        self.snapshot = snapshot
    }

    func saveRegion(_ region: AlertRegion) {
        events.values.append(.regionSaved(region))
    }

    func saveSnapshot(_ snapshot: AlertsSnapshot) {
        self.snapshot = snapshot
        events.values.append(.snapshotSaved)
    }

    func loadSnapshot() -> AlertsSnapshot? {
        snapshot
    }
}

@MainActor
private final class StatusWidgetReloaderSpy: WidgetReloading, @unchecked Sendable {
    private let events: PersistenceEvents

    init(events: PersistenceEvents) {
        self.events = events
    }

    func reloadAllTimelines() {
        events.values.append(.widgetsReloaded)
    }
}
