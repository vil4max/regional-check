import DriveCheckKit
import Foundation
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

    /// The Siri answer applies the same rule and the same unconstrained intervals as the app, so
    /// the two cannot disagree on fresh data: at each phase's boundary, the answer gains its age
    /// exactly when `DataFreshness` says stale.
    @Test(
        "REQ-REFRESH-006 REQ-SURF-011 the Siri answer turns stale where the shared rule does",
        arguments: [(AlertStatus.quiet, RefreshPolicy.baselineSeconds), (.alarm, RefreshPolicy.alarmSeconds)]
    )
    func siriAnswerFollowsSharedRule(status: AlertStatus, interval: TimeInterval) {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        for age in [interval * 2, interval * 2 + 1] {
            let checkedAt = now.addingTimeInterval(-age)
            let snapshot = AlertsSnapshot(
                source: "test",
                serverCachedAt: checkedAt,
                fetchedAt: checkedAt,
                statuses: [.kyivCity: status]
            )
            let answer = AlertStatusAnswerBuilder.answer(
                for: .kyivCity,
                snapshot: snapshot,
                now: now,
                locale: Locale(identifier: "en_US")
            )
            let isStale = DataFreshness.isStale(checkedAt: checkedAt, now: now, refreshIntervalSeconds: interval)
            #expect(answer.supporting.contains("\n") == isStale)
            #expect(isStale == (age > interval * 2))
        }
    }
}
