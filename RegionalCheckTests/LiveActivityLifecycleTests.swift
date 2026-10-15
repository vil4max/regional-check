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

    @Test(
        "REQ-SURF-009 without an alert no activity starts, even with the app open",
        arguments: [
            DriveCheckActivityPhase.quiet, .idle, .error,
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

    @Test(
        "REQ-SURF-009 a failed or not-yet-known refresh never ends the activity",
        arguments: [
            DriveCheckActivityPhase.error, .idle,
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
            preference: FixedTestLiveActivityPreference(isEnabled: false),
            entitlementChanges: { AsyncStream { $0.finish() } },
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: false),
            host: FixtureLiveActivityHost()
        )
        controller.beginPhoneForegroundSession()
        controller.beginCarPlaySession()

        controller.endAll()

        #expect(controller.clients == [.phoneForeground, .carPlay])
    }

    @Test
    @MainActor
    func serialPipeline_finishesSuspendedWorkBeforeTheNext() async {
        let log = PipelineLog()
        let pipeline = LiveActivitySerialPipeline()

        pipeline.enqueue {
            log.events.append("first began")
            await Task.yield()
            log.events.append("first ended")
        }
        pipeline.enqueue {
            log.events.append("second")
        }
        await pipeline.drain()

        #expect(log.events == ["first began", "first ended", "second"])
    }

    @Test("REQ-SURF-009 Refresh in a process launched only for it adopts or ends the activity, never starts one")
    func refreshWithoutSessionNeverStarts() {
        func background(_ phase: DriveCheckActivityPhase, hasSystemActivities: Bool)
            -> LiveActivityLifecyclePolicy
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
private final class PipelineLog {
    var events: [String] = []
}
