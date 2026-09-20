import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct StatusControllerConcurrencyTests {
    @Test("REQ-REFRESH-001 a pull during an in-flight refresh waits for it instead of returning empty-handed")
    @MainActor
    func userRefresh_whileAlreadyLoading_joinsTheInFlightRequest() async {
        let provider = BlockingStatusProvider(snapshot: TestFixtures.quietSnapshot())
        let controller = StatusController(
            region: .kyivCity,
            provider: provider,
            persistence: EmptyStatusPersistence(),
            widgetReloader: NoOpWidgetReloader()
        )

        let scheduled = Task { @MainActor in
            await controller.refresh(isScheduled: true)
        }
        await provider.waitUntilStarted()

        // During an alarm a scheduled poll is in flight most of the time. A pull that returns at
        // once snaps the spinner back with nothing to show, under copy that says "pull to refresh".
        var pullFinished = false
        let pull = Task { @MainActor in
            await controller.refresh()
            pullFinished = true
        }
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(!pullFinished)

        provider.release()
        await pull.value
        await scheduled.value
        #expect(provider.requestCount() == 1)
        #expect(controller.state.phase == .quiet)
    }

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

        // A scheduled poll never waits: the timer loop must not pile up behind a slow request.
        await controller.refresh(isScheduled: true)
        #expect(provider.requestCount() == 1)
        #expect(controller.isLoading)

        provider.release()
        await firstRefresh.value
        #expect(!controller.isLoading)
        #expect(controller.state.phase == .quiet)
    }

    @Test(.timeLimit(.minutes(1)))
    func awaitStatusSettled_whenNoRefreshEverRuns_returnsAfterTimeout() async {
        let controller = makeController(
            provider: BlockingStatusProvider(snapshot: TestFixtures.quietSnapshot()),
            statusSettledTimeout: .milliseconds(50)
        )

        await controller.awaitStatusSettled()

        #expect(!controller.isLoading)
    }

    @Test(.timeLimit(.minutes(1)))
    func awaitStatusSettled_whenWaitingTaskIsCancelled_returnsBeforeRefreshSettles() async {
        let provider = BlockingStatusProvider(snapshot: TestFixtures.quietSnapshot())
        let controller = makeController(provider: provider, statusSettledTimeout: .seconds(600))
        let refresh = Task { @MainActor in
            await controller.refresh()
        }
        await provider.waitUntilStarted()

        let waiter = Task { @MainActor in
            await controller.awaitStatusSettled()
        }
        waiter.cancel()
        await waiter.value

        #expect(controller.isLoading)
        provider.release()
        await refresh.value
    }

    @Test(.timeLimit(.minutes(1)))
    func awaitStatusSettled_whileRefreshing_resumesWhenRefreshSettles() async {
        let provider = BlockingStatusProvider(snapshot: TestFixtures.quietSnapshot())
        let controller = makeController(provider: provider, statusSettledTimeout: .seconds(600))
        let refresh = Task { @MainActor in
            await controller.refresh()
        }
        await provider.waitUntilStarted()

        let waiter = Task { @MainActor in
            await controller.awaitStatusSettled()
        }
        provider.release()
        await refresh.value
        await waiter.value

        #expect(!controller.isLoading)
    }

    /// The upstream host rate-limits the status JSON and the map raster
    /// together, so the first map request must follow the status fetch.
    @Test(.timeLimit(.minutes(1)))
    func mapAppear_duringStatusRefresh_requestsMapOnlyAfterStatusSettlesAndDelay() async {
        let provider = BlockingStatusProvider(snapshot: TestFixtures.quietSnapshot())
        let controller = makeController(provider: provider, statusSettledTimeout: .seconds(600))
        let events = EventLog()
        let mapClient = EventLoggingHTTPClient(events: events)
        let map = MapViewModel(
            statusSource: controller,
            httpClient: mapClient,
            sleep: { events.append("delay \($0)") }
        )

        let refresh = Task { @MainActor in
            await controller.refresh()
            events.append("status settled")
        }
        await provider.waitUntilStarted()
        map.appear()

        provider.release()
        await refresh.value
        while map.isLoading {
            try? await Task.sleep(for: .milliseconds(5))
        }

        // A strict prefix would only prove the request never fires early under this
        // run's particular scheduling; exact equality already proves that and needs
        // no separate load-sensitive checkpoint.
        #expect(events.entries == ["status settled", "delay 1.5 seconds", "map request"])
    }

    private func makeController(
        provider: BlockingStatusProvider,
        statusSettledTimeout: Duration
    ) -> StatusController {
        StatusController(
            region: .kyivCity,
            provider: provider,
            persistence: EmptyStatusPersistence(),
            widgetReloader: NoOpWidgetReloader(),
            statusSettledTimeout: statusSettledTimeout
        )
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

@MainActor
private final class EventLog {
    private(set) var entries: [String] = []

    func append(_ entry: String) {
        entries.append(entry)
    }
}

@MainActor
private final class EventLoggingHTTPClient: HTTPClient {
    private let events: EventLog

    init(events: EventLog) {
        self.events = events
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        events.append("map request")
        let url = request.url ?? MapImageSource.url(for: .day)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        return (Data([0x0A]), response ?? URLResponse())
    }
}
