import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// REQ-SURF-014: only the server knows when a region's alarm started. The app carries the start an
/// activity shows into its own updates, drops it when the region changes or the alarm ends, and
/// never invents one for an activity it requests itself.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct LiveActivityAlertStartTests {
    private static let startedAt = Date(timeIntervalSince1970: 1_789_555_000)
    private static let pushedCheck = Date(timeIntervalSince1970: 1_789_555_260)
    private static let appCheck = Date(timeIntervalSince1970: 1_789_555_320)
    private let host = FixtureLiveActivityHost()

    private func makeController() -> LiveActivityController {
        LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: true),
            liveActivityPermission: SilentAllowedPermission(),
            host: host
        )
    }

    private func show(
        _ phase: DriveCheckActivityPhase, region: String, at checkedAt: Date, feedStart: Date? = nil,
        on controller: LiveActivityController
    ) async {
        controller.update(
            DriveCheckActivityAttributes.ContentState(
                phase: phase, regionTitle: region, checkedAt: checkedAt, sourceLabel: "Ubilling",
                alertStartedAt: feedStart))
        await controller.settle()
    }

    /// The server's push-started activity, held once `activityUpdates` reports it.
    private func pushStarted(on controller: LiveActivityController) async {
        host.startByPush(checkedAt: Self.pushedCheck, regionTitle: "Kharkiv", alertStartedAt: Self.startedAt)
        for _ in 0..<50 { await Task.yield() }
        await controller.settle()
    }

    private var lastUpdate: DriveCheckActivityAttributes.ContentState? {
        host.calls.reversed().lazy.compactMap { call -> DriveCheckActivityAttributes.ContentState? in
            if case .update(_, let state, _) = call { state } else { nil }
        }.first
    }

    @Test("REQ-SURF-014 an update keeps the server's alert start for the same region")
    func updateKeepsTheServersStart() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await pushStarted(on: controller)

        await show(.alarm, region: "Kharkiv", at: Self.appCheck, on: controller)

        #expect(lastUpdate?.checkedAt == Self.appCheck)
        #expect(lastUpdate?.alertStartedAt == Self.startedAt)
    }

    @Test("REQ-SURF-014 a region change drops the old region's alert start")
    func regionChangeDropsTheStart() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await pushStarted(on: controller)

        await show(.alarm, region: "Poltava", at: Self.appCheck, on: controller)

        #expect(lastUpdate?.regionTitle == "Poltava")
        #expect(lastUpdate?.alertStartedAt == nil)
    }

    @Test("REQ-SURF-014 an all-clear ends the activity with no alert start")
    func allClearCarriesNoStart() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await pushStarted(on: controller)

        await show(.quiet, region: "Kharkiv", at: Self.appCheck, on: controller)

        let ends = host.calls.compactMap { call -> DriveCheckActivityAttributes.ContentState? in
            if case .end(_, let state, _) = call { state } else { nil }
        }
        #expect(!ends.isEmpty)
        #expect(ends.allSatisfy { $0.alertStartedAt == nil })
    }

    @Test("REQ-SURF-014 an activity the app requests carries the start its own feed gives, and none without one")
    func appRequestedActivityTakesTheFeedStart() async {
        let feedStart = Date(timeIntervalSince1970: 1_789_554_000)
        for start in [feedStart, nil] as [Date?] {
            let host = FixtureLiveActivityHost()
            let controller = LiveActivityController(
                preference: FixedTestLiveActivityPreference(isEnabled: true),
                liveActivityPermission: SilentAllowedPermission(),
                host: host
            )
            controller.beginPhoneForegroundSession()
            controller.update(
                DriveCheckActivityAttributes.ContentState(
                    phase: .alarm, regionTitle: "Kharkiv", checkedAt: Self.appCheck, sourceLabel: "Ubilling",
                    alertStartedAt: start))
            await controller.settle()

            let requested = host.calls.compactMap { call -> DriveCheckActivityAttributes.ContentState? in
                if case .request(_, let state, _) = call { state } else { nil }
            }
            #expect(requested.count == 1)
            #expect(requested.first?.alertStartedAt == start)
        }
    }

    @Test("REQ-SURF-014 the app's own feed start wins over the start an earlier push showed")
    func feedStartWinsOverThePushedOne() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await pushStarted(on: controller)
        let feedStart = Self.startedAt.addingTimeInterval(-60)

        await show(.alarm, region: "Kharkiv", at: Self.appCheck, feedStart: feedStart, on: controller)

        #expect(lastUpdate?.alertStartedAt == feedStart)
    }
}
