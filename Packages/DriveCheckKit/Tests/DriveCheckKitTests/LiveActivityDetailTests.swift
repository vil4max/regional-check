import DriveCheckKit
import Foundation
import Testing

/// REQ-SURF-014: the one line under a Live Activity's state and region. A fresh alarm whose start
/// the server knows shows how long ago it started; everything else shows its check time.
struct LiveActivityDetailTests {
    private static let startedAt = Date(timeIntervalSinceReferenceDate: 816_175_000)
    private static let checkedAt = Date(timeIntervalSinceReferenceDate: 816_175_714)

    private func state(
        _ phase: DriveCheckActivityPhase, checkedAt: Date? = checkedAt, startedAt: Date? = startedAt
    ) -> DriveCheckActivityAttributes.ContentState {
        DriveCheckActivityAttributes.ContentState(
            phase: phase, regionTitle: "Kyiv", checkedAt: checkedAt, sourceLabel: "",
            alertStartedAt: startedAt)
    }

    @Test("REQ-SURF-014 a fresh alarm with a known start shows how long ago it started")
    func freshAlarmShowsItsStart() {
        #expect(state(.alarm).liveActivityDetail(isStale: false) == .started(Self.startedAt))
    }

    @Test("REQ-SURF-014 a stale alarm shows its check time, never a running duration")
    func staleAlarmShowsItsCheck() {
        // REQ-SURF-003: the alarm may already be over, so nothing may keep counting.
        #expect(state(.alarm).liveActivityDetail(isStale: true) == .checked(Self.checkedAt))
    }

    @Test("REQ-SURF-014 no start, a quiet region and checking show the check time or nothing")
    func otherStatesShowTheirCheck() {
        #expect(state(.alarm, startedAt: nil).liveActivityDetail(isStale: false) == .checked(Self.checkedAt))
        #expect(state(.quiet).liveActivityDetail(isStale: false) == .checked(Self.checkedAt))
        #expect(state(.error).liveActivityDetail(isStale: false) == .checked(Self.checkedAt))
        #expect(state(.idle, checkedAt: nil).liveActivityDetail(isStale: false) == LiveActivityDetail.none)
    }
}
