import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct LiveActivityLifecycleTests {
    private func action(
        canRun: Bool = true,
        _ phase: DriveCheckActivityPhase,
        hasSession: Bool,
        hasActivity: Bool
    ) -> LiveActivityLifecyclePolicy.Action {
        LiveActivityLifecyclePolicy.nextAction(
            canRun: canRun, phase: phase, hasSession: hasSession, hasActivity: hasActivity
        )
    }

    @Test("REQ-SURF-009 an alert seen by the app or CarPlay starts the activity")
    func alarmInASessionStarts() {
        #expect(action(.alarm, hasSession: true, hasActivity: false) == .start)
    }

    @Test("REQ-SURF-009 without an alert no activity starts, even with the app open", arguments: [
        DriveCheckActivityPhase.quiet, .idle, .error
    ])
    func noAlarmStartsNothing(phase: DriveCheckActivityPhase) {
        #expect(action(phase, hasSession: true, hasActivity: false) == .none)
    }

    @Test("REQ-SURF-009 minimising the app keeps a running alert activity")
    func leavingTheSessionKeepsTheActivity() {
        #expect(action(.alarm, hasSession: false, hasActivity: true) == .update)
    }

    @Test("REQ-SURF-009 a confirmed all-clear ends the activity, in a session or not", arguments: [true, false])
    func allClearEnds(hasSession: Bool) {
        #expect(action(.quiet, hasSession: hasSession, hasActivity: true) == .terminate)
    }

    @Test("REQ-SURF-009 a failed or not-yet-known refresh never ends the activity", arguments: [
        DriveCheckActivityPhase.error, .idle
    ])
    func unknownPhaseKeepsTheActivity(phase: DriveCheckActivityPhase) {
        #expect(action(phase, hasSession: true, hasActivity: true) == .update)
    }

    @Test("REQ-SURF-009 an alert without a session cannot start one: ActivityKit starts from the foreground")
    func alarmWithoutSessionDoesNotStart() {
        #expect(action(.alarm, hasSession: false, hasActivity: false) == .none)
    }

    @Test("REQ-SURF-008 turning Live Activities off ends a running activity")
    func cannotRunTerminates() {
        #expect(action(canRun: false, .alarm, hasSession: true, hasActivity: true) == .terminate)
        #expect(action(canRun: false, .alarm, hasSession: true, hasActivity: false) == .none)
    }

    @Test("REQ-SURF-003 ending the activity keeps the connected CarPlay client, so re-enabling restores it")
    @MainActor
    func endAll_keepsConnectedClients() {
        let controller = LiveActivityController(
            allowsLiveActivity: { false },
            entitlementChanges: { AsyncStream { $0.finish() } }
        )
        controller.beginPhoneForegroundSession()
        controller.beginCarPlaySession()

        controller.endAll()

        #expect(controller.clients == [.phoneForeground, .carPlay])
    }

    @Test
    @MainActor
    func serialPipeline_clearsActivityBeforeAwaitingEnd() async {
        let session = RecordingActivitySession()
        let pipeline = LiveActivitySerialPipeline()

        pipeline.enqueue {
            await session.terminateClearingBeforeEnd()
        }
        pipeline.enqueue {
            await session.startIfNeeded()
        }
        await pipeline.drain()

        #expect(session.events == [.cleared, .ended, .started])
        #expect(session.hasActivity)
    }

    @Test("REQ-SURF-009 Refresh in a process launched only for it adopts or ends the activity, never starts one")
    func refreshWithoutSessionNeverStarts() {
        func background(_ phase: DriveCheckActivityPhase, hasSystemActivities: Bool) -> LiveActivityLifecyclePolicy
            .Action
        {
            LiveActivityLifecyclePolicy.nextAction(
                canRun: true,
                phase: phase,
                hasSession: false,
                hasActivity: false,
                hasSystemActivities: hasSystemActivities
            )
        }
        #expect(background(.alarm, hasSystemActivities: true) == .adopt)
        #expect(background(.quiet, hasSystemActivities: true) == .endOrphans)
        #expect(background(.alarm, hasSystemActivities: false) == .none)
    }
}

@MainActor
private final class RecordingActivitySession {
    enum Event: Equatable {
        case cleared
        case ended
        case started
    }

    private(set) var events: [Event] = []
    private(set) var hasActivity = true

    func terminateClearingBeforeEnd() async {
        guard hasActivity else { return }
        hasActivity = false
        events.append(.cleared)
        try? await Task.sleep(for: .milliseconds(20))
        events.append(.ended)
    }

    func startIfNeeded() async {
        guard !hasActivity else { return }
        hasActivity = true
        events.append(.started)
    }
}
