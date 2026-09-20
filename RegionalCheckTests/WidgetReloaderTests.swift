@testable import RegionalCheck
import Synchronization
import Testing

@MainActor
struct WidgetReloaderTests {
    @Test("REQ-SURF-003 reloading widget timelines also reloads the Control Center control")
    func reloadAllTimelinesReloadsControls() {
        let calls = Mutex<[String]>([])
        let reloader = LiveWidgetReloader(
            reloadTimelines: { calls.withLock { $0.append("timelines") } },
            reloadControls: { calls.withLock { $0.append("controls") } }
        )

        reloader.reloadAllTimelines()

        #expect(calls.withLock { $0 } == ["timelines", "controls"])
    }
}
