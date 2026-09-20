@testable import RegionalCheck
import Testing

/// An activity that outlived the process is invisible to the controller's own `activity`
/// reference; only the system's list reveals it.
struct LiveActivityAdoptionTests {
    @Test("REQ-SURF-003 a launch that wants an activity adopts the surviving one instead of requesting a second")
    func adoptsSurvivingActivityInsteadOfStarting() {
        #expect(
            LiveActivityLifecyclePolicy.nextAction(
                canRun: true, hasClients: true, hasActivity: false, hasSystemActivities: true
            ) == .adopt
        )
    }

    @Test("REQ-SURF-003 a surviving activity nobody can update is ended, not left frozen", arguments: [
        (canRun: false, hasClients: true),
        (canRun: true, hasClients: false),
        (canRun: false, hasClients: false)
    ])
    func endsOrphansWhenNoActivityIsWanted(canRun: Bool, hasClients: Bool) {
        #expect(
            LiveActivityLifecyclePolicy.nextAction(
                canRun: canRun, hasClients: hasClients, hasActivity: false, hasSystemActivities: true
            ) == .endOrphans
        )
    }

    @Test("An owned activity is updated or terminated as before, whatever the system list holds")
    func ownedActivityTakesPrecedence() {
        #expect(
            LiveActivityLifecyclePolicy.nextAction(
                canRun: true, hasClients: true, hasActivity: true, hasSystemActivities: true
            ) == .update
        )
        #expect(
            LiveActivityLifecyclePolicy.nextAction(
                canRun: false, hasClients: true, hasActivity: true, hasSystemActivities: true
            ) == .terminate
        )
    }

    @Test("Without a surviving activity a wanted activity is still requested")
    func startsWhenNothingSurvived() {
        #expect(
            LiveActivityLifecyclePolicy.nextAction(
                canRun: true, hasClients: true, hasActivity: false, hasSystemActivities: false
            ) == .start
        )
    }
}
