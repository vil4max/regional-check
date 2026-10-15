import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct FetchGateTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test("REQ-REFRESH-010 every trigger is held inside the floor after a success")
    func floorHoldsEveryTrigger() {
        var gate = FetchGate()
        gate.recordSuccess(at: start)

        #expect(gate.isHeld(isScheduled: true, now: start.addingTimeInterval(9)))
        #expect(gate.isHeld(isScheduled: false, now: start.addingTimeInterval(9)))
        #expect(!gate.isHeld(isScheduled: false, now: start.addingTimeInterval(FetchGate.floor)))
    }

    @Test("REQ-REFRESH-005 a rate-limit window holds scheduled polls and lets a manual refresh through")
    func windowHoldsOnlyScheduledPolls() {
        var gate = FetchGate()
        gate.recordRateLimit(until: start.addingTimeInterval(120), now: start)

        #expect(gate.isRateLimited(now: start.addingTimeInterval(60)))
        #expect(gate.isHeld(isScheduled: true, now: start.addingTimeInterval(60)))
        #expect(!gate.isHeld(isScheduled: false, now: start.addingTimeInterval(60)))
        #expect(!gate.isHeld(isScheduled: true, now: start.addingTimeInterval(120)))
    }

    @Test("REQ-REFRESH-005 a successful manual refresh does not end the window early")
    func manualSuccessKeepsTheWindow() {
        var gate = FetchGate()
        gate.recordRateLimit(until: start.addingTimeInterval(120), now: start)
        gate.recordSuccess(at: start.addingTimeInterval(30))

        #expect(gate.isHeld(isScheduled: true, now: start.addingTimeInterval(60)))
    }

    @Test("REQ-REFRESH-005 a window further than five minutes ahead is capped")
    func windowIsCapped() {
        var gate = FetchGate()
        let until = gate.recordRateLimit(until: start.addingTimeInterval(86_400), now: start)

        #expect(until == start.addingTimeInterval(RetryAfterParser.maxHold))
        #expect(!gate.isHeld(isScheduled: true, now: start.addingTimeInterval(RetryAfterParser.maxHold)))
    }
}
