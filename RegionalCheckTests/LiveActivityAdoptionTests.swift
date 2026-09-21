import DriveCheckKit
@testable import RegionalCheck
import Testing

/// An activity that outlived the process is invisible to the controller's own `activity`
/// reference; only the system's list reveals it.
struct LiveActivityAdoptionTests {
    private func action(
        canRun: Bool = true,
        _ phase: DriveCheckActivityPhase,
        hasSession: Bool = true,
        hasActivity: Bool = false,
        hasSystemActivities: Bool = true
    ) -> LiveActivityLifecyclePolicy.Action {
        LiveActivityLifecyclePolicy.nextAction(
            canRun: canRun,
            phase: phase,
            hasSession: hasSession,
            hasActivity: hasActivity,
            hasSystemActivities: hasSystemActivities
        )
    }

    @Test("REQ-SURF-009 a launch during the alert adopts the surviving activity instead of requesting a second")
    func adoptsSurvivingActivityDuringAlarm() {
        #expect(action(.alarm) == .adopt)
    }

    @Test("REQ-SURF-009 a surviving activity is ended once the app sees the all-clear")
    func endsSurvivorsOnAllClear() {
        #expect(action(.quiet) == .endOrphans)
    }

    @Test("REQ-SURF-003 a surviving alert stays on screen until the region is known again", arguments: [
        DriveCheckActivityPhase.idle, .error
    ])
    func keepsSurvivorsWhileUnknown(phase: DriveCheckActivityPhase) {
        #expect(action(phase) == .none)
    }

    @Test("REQ-SURF-008 surviving activities are ended when Live Activities are off")
    func endsSurvivorsWhenTheyCannotRun() {
        #expect(action(canRun: false, .alarm) == .endOrphans)
    }

    @Test("An owned activity is updated or terminated whatever the system list holds")
    func ownedActivityTakesPrecedence() {
        #expect(action(.alarm, hasActivity: true) == .update)
        #expect(action(.quiet, hasActivity: true) == .terminate)
    }

    @Test("Without a surviving activity an alert in a session still requests one")
    func startsWhenNothingSurvived() {
        #expect(action(.alarm, hasSystemActivities: false) == .start)
    }
}
