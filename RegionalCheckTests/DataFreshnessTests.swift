import Foundation
@testable import RegionalCheck
import Testing

struct DataFreshnessTests {
    @Test("REQ-REFRESH-006 data is stale once it is older than twice the base interval")
    func marksStaleAfterTwoIntervals() {
        let checkedAt = Date(timeIntervalSince1970: 0)
        #expect(
            DataFreshness.isStale(
                checkedAt: checkedAt,
                now: Date(timeIntervalSince1970: 121),
                refreshIntervalSeconds: 60
            )
        )
        #expect(
            DataFreshness.isStale(
                checkedAt: checkedAt,
                now: Date(timeIntervalSince1970: 120),
                refreshIntervalSeconds: 60
            ) == false
        )
    }
}
