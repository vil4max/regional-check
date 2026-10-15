import Foundation

/// Whether `condition` holds before `timeout` elapses. Use it as
/// `try #require(await eventually { ... })` so a timeout fails at the wait instead of surfacing
/// as an unrelated assertion later, or not at all.
///
/// Bounded by the clock rather than by a count of yields, which a loaded runner can use up before
/// the update arrives. The default is generous because it only matters when the condition never
/// holds, and shared CI and gate hosts run far slower than a developer machine. `#isolation` keeps
/// the condition on the caller's actor, so it can read main-actor state without sending the
/// closure across an isolation boundary.
func eventually(
    timeout: Duration = .seconds(15),
    isolation _: isolated (any Actor)? = #isolation,
    _ condition: () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition() {
        guard ContinuousClock.now < deadline, !Task.isCancelled else { return false }
        await Task.yield()
        // A cancelled sleep returns at once; the guard above then ends the wait instead of spinning.
        try? await Task.sleep(for: .milliseconds(2))
    }
    return true
}
