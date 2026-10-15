import Synchronization

/// Holds main-actor changes a production scheduler would run later (for example
/// `StatusController`'s `scheduleRegionChange`), so a test decides when they run with `drain()`.
final class ScheduledChangeQueue: Sendable {
    private let changes = Mutex<[@MainActor @Sendable () -> Void]>([])
    var count: Int { changes.withLock { $0.count } }
    var isEmpty: Bool { changes.withLock { $0.isEmpty } }

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
