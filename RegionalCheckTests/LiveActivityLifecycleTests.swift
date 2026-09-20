import Foundation
@testable import RegionalCheck
import Testing

struct LiveActivityLifecycleTests {
    @Test
    func nextAction_terminatesWhenNoClientsAndActivityExists() {
        #expect(
            LiveActivityLifecyclePolicy.nextAction(canRun: true, hasClients: false, hasActivity: true)
                == .terminate
        )
    }

    @Test
    func nextAction_startsWhenClientsPresentAndNoActivity() {
        #expect(
            LiveActivityLifecyclePolicy.nextAction(canRun: true, hasClients: true, hasActivity: false)
                == .start
        )
    }

    @Test
    func nextAction_updatesWhenActivityAlreadyRunning() {
        #expect(
            LiveActivityLifecyclePolicy.nextAction(canRun: true, hasClients: true, hasActivity: true)
                == .update
        )
    }

    @Test
    func nextAction_doesNothingWhenCannotRunWithoutActivity() {
        #expect(
            LiveActivityLifecyclePolicy.nextAction(canRun: false, hasClients: true, hasActivity: false)
                == .none
        )
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
