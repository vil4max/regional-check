@testable import RegionalCheck
import Testing

/// Tests the ordering `ColdStartSettling.awaitIfNeeded` guarantees, not timing: a cached status
/// must never invoke `awaitStatusSettled` at all, regardless of how long that closure would take
/// to resolve. A duration-based assertion (e.g. "finishes within 400 ms") would be flaky under
/// load and would pass on a fast network even if the call still happened, which is exactly how
/// the bug this covers went unnoticed — the phase logic was already correct and unit-tested, and
/// a concurrently started refresh's `isLoading` defeated it at runtime regardless.
struct ColdStartSettlingTests {
    @Test("REQ-LAUNCH-002/003 a cached status never awaits settle, however long that closure hangs")
    func cachedStatusNeverAwaitsSettle() async {
        var wasCalled = false
        await ColdStartSettling.awaitIfNeeded(hasCachedStatus: true) {
            wasCalled = true
            // Long enough that this test would visibly hang, not just run slow, if the guard in
            // `awaitIfNeeded` were ever removed or bypassed.
            try? await Task.sleep(for: .seconds(3600))
        }
        #expect(wasCalled == false)
    }

    @Test("REQ-LAUNCH-002 no cached status still awaits settle, bounded by its own timeout")
    func noCachedStatusAwaitsSettle() async {
        var wasCalled = false
        await ColdStartSettling.awaitIfNeeded(hasCachedStatus: false) {
            wasCalled = true
        }
        #expect(wasCalled == true)
    }
}
