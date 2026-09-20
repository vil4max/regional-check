import Foundation
@testable import RegionalCheck

/// A clock a test can move. `StatusController` holds a second fetch that follows a successful
/// one by less than `fetchFloor` (REQ-REFRESH-010), so a test that needs two real fetches has to
/// say that time passed between them instead of issuing both at one frozen instant.
@MainActor
final class TestClock {
    private(set) var now: Date

    init(_ start: Date = Date(timeIntervalSince1970: 10000)) {
        now = start
    }

    func advancePastFetchFloor() {
        now = now.addingTimeInterval(StatusController.fetchFloor)
    }
}
