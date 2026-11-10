import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The Live Activity controller's side of ALERT-push: tokens reach the server, activities the
/// server starts by push are held, never doubled, and never ended on old data.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct LiveActivityPushTests {
    private static let alarmAt = Date(timeIntervalSince1970: 1_789_555_260)
    private let host = FixtureLiveActivityHost()
    private let sink = RecordingTokenSink()

    private func makeController() -> LiveActivityController {
        let controller = LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: true),
            liveActivityPermission: SilentAllowedPermission(),
            host: host
        )
        controller.tokenSink = sink
        return controller
    }

    private func show(
        _ phase: DriveCheckActivityPhase, at checkedAt: Date?, isStale: Bool = false,
        on controller: LiveActivityController
    ) async {
        controller.update(
            phase: phase, regionTitle: "Kharkiv", checkedAt: checkedAt, sourceLabel: "Ubilling", isStale: isStale)
        await controller.settle()
    }

    /// Token streams are drained by tasks of their own, so a fixed number of yields is not enough
    /// on a loaded CI runner: with `until`, wait for the expected effect (bounded), then drain.
    private func settle(_ controller: LiveActivityController, until done: (() -> Bool)? = nil) async {
        for step in 0..<2_000 {
            if let done, done() { break }
            if done == nil, step >= 20 { break }
            await Task.yield()
        }
        await controller.settle()
    }

    @Test("ALERT-push AC-9 an activity the app requests forwards its update token to the server")
    func requestedActivityForwardsItsToken() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await show(.alarm, at: Self.alarmAt, on: controller)

        host.handle(1)?.emitToken(Data([0xAB]))
        await settle(controller) { sink.activityTokens.count == 1 }

        #expect(sink.activityTokens == [Data([0xAB])])
    }

    @Test("ALERT-push AC-2 the push-to-start token and the allowed state reach the server")
    func startTokenAndAllowedStateReachTheSink() async {
        let controller = makeController()

        host.emitStartToken(Data([0x01]))
        await settle(controller) { sink.startTokens.count == 1 }

        #expect(sink.startTokens == [Data([0x01])])
        #expect(sink.allowed.last == true)
    }

    @Test("ALERT-push point 1 an activity started by push while the app is idle is held and its token sent")
    func pushStartedActivityIsHeldWhateverThePhase() async {
        let controller = makeController()

        let pushed = host.startByPush(checkedAt: Self.alarmAt)
        await settle(controller)
        pushed.emitToken(Data([0xCD]))
        await settle(controller) { sink.activityTokens.count == 1 }

        #expect(sink.activityTokens == [Data([0xCD])])
        // The app has no data of its own yet, so it must not overwrite the server's red content.
        #expect(!host.calls.contains { if case .update = $0 { true } else { false } })
        #expect(!host.calls.contains { if case .end = $0 { true } else { false } })
    }

    @Test("ALERT-push AC-7 a second activity is ended and the held one kept")
    func secondActivityIsEnded() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await show(.alarm, at: Self.alarmAt, on: controller)

        let pushed = host.startByPush(checkedAt: Self.alarmAt)
        await settle(controller)

        #expect(host.calls.contains(.end(id: pushed.id, state: nil, dismissal: .immediate)))
        #expect(host.handle(1) != nil)
    }

}

/// Handing over between activities: ended, tokenless, switched off, late sink, region change.
extension LiveActivityPushTests {
    @Test("ALERT-push AC-7 an activity the system ended is let go, so the next alarm's push-started one stays")
    func activityEndedBySystemIsReleased() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await show(.alarm, at: Self.alarmAt, on: controller)
        // The server's all-clear `end` push, the 8-hour limit or the driver's swipe.
        host.endBySystem(1)

        let next = host.startByPush(checkedAt: Self.alarmAt.addingTimeInterval(3600))
        await settle(controller)
        next.emitToken(Data([0xEF]))
        await settle(controller)

        #expect(host.handle(next.id) != nil)
        #expect(!host.calls.contains(.end(id: next.id, state: nil, dismissal: .immediate)))
        #expect(sink.activityTokens.last == .some(Data([0xEF])))
    }

    @Test("ALERT-push AC-9 a survivor without a push token gives way to the server's activity")
    func tokenlessSurvivorGivesWay() async {
        let controller = makeController()
        let old = host.addSurvivor(hasPushToken: false)
        controller.beginPhoneForegroundSession()
        await show(.alarm, at: Self.alarmAt, on: controller)

        let pushed = host.startByPush(checkedAt: Self.alarmAt)
        await settle(controller)

        #expect(host.handle(old) == nil)
        #expect(host.handle(pushed.id) != nil)
    }

    @Test("ALERT-push AC-7 adoption prefers a survivor the server can end")
    func adoptionPrefersATokenBearingSurvivor() async {
        let controller = makeController()
        let old = host.addSurvivor(hasPushToken: false)
        let current = host.addSurvivor()
        controller.beginPhoneForegroundSession()
        await show(.alarm, at: Self.alarmAt, on: controller)

        #expect(host.handle(old) == nil)
        #expect(host.handle(current) != nil)
    }

    @Test("ALERT-push REQ-SURF-008 an activity started by push while Live Activities are off is ended")
    func pushStartedActivityIsEndedWhenSwitchedOff() async {
        let controller = LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: false),
            liveActivityPermission: SilentAllowedPermission(),
            host: host
        )
        controller.tokenSink = sink

        let pushed = host.startByPush(checkedAt: Self.alarmAt)
        await settle(controller)

        #expect(host.handle(pushed.id) == nil)
        #expect(sink.activityTokens.isEmpty)
    }

    @Test("ALERT-push AC-9 the held activity's token reaches a sink set after it arrived")
    func heldTokenIsReplayedToALateSink() async {
        let controller = LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: true),
            liveActivityPermission: SilentAllowedPermission(),
            host: host
        )
        let pushed = host.startByPush(checkedAt: Self.alarmAt)
        await settle(controller)
        pushed.emitToken(Data([0xCD]))
        await settle(controller)

        controller.tokenSink = sink

        #expect(sink.activityTokens == [Data([0xCD])])
    }

    @Test("ALERT-push AC-11 a region change shows the new region, and a quiet one ends green after 5 minutes")
    func regionChangeFollowsTheNewRegion() async {
        let controller = LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: true),
            liveActivityPermission: SilentAllowedPermission(),
            host: host,
            now: { Self.alarmAt }
        )
        controller.beginPhoneForegroundSession()
        await show(.alarm, at: Self.alarmAt, on: controller)

        let moved = Self.alarmAt.addingTimeInterval(300)
        controller.update(phase: .alarm, regionTitle: "Poltava", checkedAt: moved, sourceLabel: "Ubilling")
        await controller.settle()
        let shown = host.calls.last.flatMap { if case .update(_, let state, _) = $0 { state } else { nil } }
        #expect(shown?.regionTitle == "Poltava")

        let quietAt = moved.addingTimeInterval(300)
        controller.update(phase: .quiet, regionTitle: "Sumy", checkedAt: quietAt, sourceLabel: "Ubilling")
        await controller.settle()
        guard case .end(1, let state, let dismissal) = host.calls.last else {
            Issue.record("expected the activity to end, got \(host.calls)")
            return
        }
        #expect(state?.regionTitle == "Sumy")
        #expect(state?.phase == .quiet)
        #expect(dismissal == .after(Self.alarmAt.addingTimeInterval(300)))
    }

    @Test("ALERT-push point 3 a saved older quiet status never ends the server's alarm; a newer fresh one does")
    func onlyANewerFreshAllClearEnds() async {
        let controller = makeController()
        let pushed = host.startByPush(checkedAt: Self.alarmAt)
        await settle(controller)

        await show(.quiet, at: Self.alarmAt.addingTimeInterval(-600), on: controller)
        #expect(host.handle(pushed.id) != nil)

        await show(.quiet, at: Self.alarmAt.addingTimeInterval(600), isStale: true, on: controller)
        #expect(host.handle(pushed.id) != nil)

        await show(.quiet, at: Self.alarmAt.addingTimeInterval(600), on: controller)
        #expect(host.handle(pushed.id) == nil)
        #expect(sink.activityTokens.last == .some(nil))
    }
}

@MainActor
final class RecordingTokenSink: LiveActivityTokenSink {
    private(set) var startTokens: [Data] = []
    private(set) var activityTokens: [Data?] = []
    private(set) var allowed: [Bool] = []

    func startTokenDidChange(_ token: Data) { startTokens.append(token) }
    func activityTokenDidChange(_ token: Data?) { activityTokens.append(token) }
    func liveActivitiesAllowedDidChange(_ allowed: Bool) { self.allowed.append(allowed) }
}
