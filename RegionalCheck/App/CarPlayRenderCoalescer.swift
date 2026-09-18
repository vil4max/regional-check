import Foundation

/// What the driver currently sees, reduced to just what deciding "should this update
/// interrupt the 10 s coalescing window" needs (REQ-REFRESH data-row cadence). Two renders
/// with an equal snapshot are a no-op; a snapshot whose `isFresh`/`phase` differs from the
/// last *applied* one is a transition the driver must see immediately (fresh ↔ stale,
/// quiet ↔ alarm), regardless of how recently the last update landed.
struct CarPlayRenderSnapshot: Equatable {
    let loadState: CarPlayLoadState
    let isFresh: Bool
    let phase: StatusState.Phase?
}

enum CarPlayRenderReason: Equatable {
    case reactive
    case manualRefreshResult
}

/// Coalesces CarPlay data-row updates to at most one every 10 s (driving-task guidance:
/// don't refresh data rows more often than every 10 s), except a manual-refresh result or a
/// must-see transition, which always applies immediately. Pure and clock-injectable so it is
/// testable without any CarPlay API.
@MainActor
final class CarPlayRenderCoalescer {
    static let minInterval: Duration = .seconds(10)

    private let now: () -> Date
    private var lastApplied: CarPlayRenderSnapshot?
    private var lastAppliedAt: Date?

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    /// Records the initially-displayed snapshot so the first reactive update afterward is
    /// measured against the real connect time, not treated as an unconditional first render.
    func seed(_ snapshot: CarPlayRenderSnapshot) {
        lastApplied = snapshot
        lastAppliedAt = now()
    }

    /// Returns whether the caller should push the rebuilt templates to CarPlay. Marks the
    /// snapshot as applied when it returns `true`.
    func shouldApply(_ snapshot: CarPlayRenderSnapshot, reason: CarPlayRenderReason) -> Bool {
        guard snapshot != lastApplied else { return false }
        let mustSeeNow = reason == .manualRefreshResult || isMustSeeTransition(from: lastApplied, to: snapshot)
        let intervalElapsed = lastAppliedAt.map { now().timeIntervalSince($0) >= Self.minInterval.timeInterval } ?? true
        guard mustSeeNow || intervalElapsed else { return false }
        lastApplied = snapshot
        lastAppliedAt = now()
        return true
    }

    private func isMustSeeTransition(from old: CarPlayRenderSnapshot?, to new: CarPlayRenderSnapshot) -> Bool {
        guard let old else { return true }
        return old.isFresh != new.isFresh || old.phase != new.phase
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
