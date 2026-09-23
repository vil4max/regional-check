import Foundation
@testable import RegionalCheck
import Testing

struct LiveActivityStaleDateTests {
    @Test("REQ-REFRESH-006 the Live Activity goes stale 15 min after the data was checked")
    func usesCheckedAtPlusBackgroundHorizon() {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let stale = LiveActivityStaleDate.make(
            checkedAt: checkedAt,
            now: Date(timeIntervalSince1970: 1_700_000_500)
        )
        #expect(stale == checkedAt.addingTimeInterval(900))
    }

    @Test("REQ-REFRESH-006 without a check time the horizon starts now")
    func fallsBackToNowWhenCheckedAtMissing() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let stale = LiveActivityStaleDate.make(checkedAt: nil, now: now)
        #expect(stale == now.addingTimeInterval(900))
    }
}
