import DriveCheckKit
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

    private func makeController(
        events: PersistenceEvents,
        snapshot: AlertsSnapshot = TestFixtures.quietSnapshot()
    ) -> StatusController {
        StatusController(
            region: .kyivCity,
            provider: MockStatusProvider(snapshot: snapshot),
            persistence: StatusPersistenceSpy(events: events),
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

    init(events: PersistenceEvents) {
        self.events = events
    }

    func saveRegion(_ region: AlertRegion) {
        events.values.append(.regionSaved(region))
    }

    func saveSnapshot(_: AlertsSnapshot) {
        events.values.append(.snapshotSaved)
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
