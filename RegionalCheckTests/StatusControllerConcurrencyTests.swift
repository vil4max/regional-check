import DriveCheckKit
@testable import RegionalCheck
import Testing

@MainActor
struct StatusControllerConcurrencyTests {
    @Test
    func refresh_whileAlreadyLoading_doesNotStartSecondRequest() async {
        let provider = BlockingStatusProvider(snapshot: TestFixtures.quietSnapshot())
        let controller = StatusController(
            region: .kyivCity,
            provider: provider,
            persistence: EmptyStatusPersistence(),
            widgetReloader: NoOpWidgetReloader()
        )

        let firstRefresh = Task { @MainActor in
            await controller.refresh()
        }
        await provider.waitUntilStarted()

        await controller.refresh()
        #expect(await provider.requestCount() == 1)
        #expect(controller.isLoading)

        await provider.release()
        await firstRefresh.value
        #expect(!controller.isLoading)
        #expect(controller.state.phase == .quiet)
    }
}

@MainActor
private final class BlockingStatusProvider: StatusProviding {
    private let snapshot: AlertsSnapshot
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private(set) var count = 0
    private var hasStarted = false

    init(snapshot: AlertsSnapshot) {
        self.snapshot = snapshot
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        count += 1
        hasStarted = true
        startedContinuation?.resume()
        startedContinuation = nil
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
        return snapshot
    }

    func waitUntilStarted() async {
        if hasStarted {
            return
        }
        await withCheckedContinuation { continuation in
            startedContinuation = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func requestCount() -> Int {
        count
    }
}

@MainActor
private struct EmptyStatusPersistence: StatusPersisting {
    func saveRegion(_: AlertRegion) {}
    func saveSnapshot(_: AlertsSnapshot) {}
    func loadSnapshot() -> AlertsSnapshot? {
        nil
    }
}

@MainActor
private struct NoOpWidgetReloader: WidgetReloading {
    func reloadAllTimelines() {}
}
