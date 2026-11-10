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

    private func settle(_ controller: LiveActivityController) async {
        for _ in 0..<20 { await Task.yield() }
        await controller.settle()
    }

    @Test("ALERT-push AC-9 an activity the app requests forwards its update token to the server")
    func requestedActivityForwardsItsToken() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await show(.alarm, at: Self.alarmAt, on: controller)

        host.handle(1)?.emitToken(Data([0xAB]))
        await settle(controller)

        #expect(sink.activityTokens == [Data([0xAB])])
    }

    @Test("ALERT-push AC-2 the push-to-start token and the allowed state reach the server")
    func startTokenAndAllowedStateReachTheSink() async {
        let controller = makeController()

        host.emitStartToken(Data([0x01]))
        await settle(controller)

        #expect(sink.startTokens == [Data([0x01])])
        #expect(sink.allowed.last == true)
    }

    @Test("ALERT-push point 1 an activity started by push while the app is idle is held and its token sent")
    func pushStartedActivityIsHeldWhateverThePhase() async {
        let controller = makeController()

        let pushed = host.startByPush(checkedAt: Self.alarmAt)
        await settle(controller)
        pushed.emitToken(Data([0xCD]))
        await settle(controller)

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
