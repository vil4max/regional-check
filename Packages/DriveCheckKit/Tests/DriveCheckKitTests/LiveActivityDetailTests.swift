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

    @Test("REQ-SURF-014 VoiceOver says the state, region, start, data time and any footer, in that order")
    func spokenParts() {
        let updated = LiveActivitySpokenPart.updated(Self.checkedAt)
        #expect(
            state(.alarm).liveActivitySpokenParts(isStale: false)
                == [.state, .region, .started(Self.startedAt), updated])
        // A stale alarm drops the duration, keeps its data time and says it may be over (REQ-SURF-003).
        #expect(
            state(.alarm).liveActivitySpokenParts(isStale: true)
                == [.state, .region, updated, .footer(.mayBeOutdated)])
        #expect(state(.quiet).liveActivitySpokenParts(isStale: false) == [.state, .region, updated])
        #expect(
            state(.quiet).liveActivitySpokenParts(isStale: true) == [.state, .region, updated, .footer(.lastKnown)])
        #expect(
            state(.idle, checkedAt: nil).liveActivitySpokenParts(isStale: false)
                == [.state, .region, .footer(.checking)])
    }

    @Test("REQ-SURF-014 the data time shows in every state that has one, beside the start")
    func dataTimeIsAlwaysShown() {
        // The time of the data is the driver's one way to judge freshness (owner, 2026-11-13).
        #expect(state(.alarm).liveActivityUpdatedAt == Self.checkedAt)
        #expect(state(.quiet).liveActivityUpdatedAt == Self.checkedAt)
        #expect(state(.idle, checkedAt: nil).liveActivityUpdatedAt == nil)
    }

    @Test("REQ-SURF-014 no start, a quiet region and checking show the check time or nothing")
    func otherStatesShowTheirCheck() {
        #expect(state(.alarm, startedAt: nil).liveActivityDetail(isStale: false) == .checked(Self.checkedAt))
        #expect(state(.quiet).liveActivityDetail(isStale: false) == .checked(Self.checkedAt))
        #expect(state(.error).liveActivityDetail(isStale: false) == .checked(Self.checkedAt))
        #expect(state(.idle, checkedAt: nil).liveActivityDetail(isStale: false) == LiveActivityDetail.none)
    }
}
