import Foundation

/// Whether `condition` holds before `timeout` elapses. Use it as
/// `try #require(await eventually { ... })` so a timeout fails at the wait instead of surfacing
/// as an unrelated assertion later, or not at all.
///
/// Bounded by the clock rather than by a count of yields, which a loaded runner can use up before
/// the update arrives. `#isolation` keeps the condition on the caller's actor, so it can read
/// main-actor state without sending the closure across an isolation boundary.
func eventually(
    timeout: Duration = .seconds(5),
    isolation _: isolated (any Actor)? = #isolation,
    _ condition: () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(2))
    }
    return true
}
