import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The real controller against ActivityKit replaced by `FixtureLiveActivityHost`: what the
/// lifecycle policy decides, and which ActivityKit calls carry it out.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct LiveActivityControllerTests {
    private static let checkedAt = Date(timeIntervalSince1970: 1_789_555_260)
    private static let staleDate = checkedAt.addingTimeInterval(LiveActivityStaleDate.backgroundHorizon)

    private let host = FixtureLiveActivityHost()

    private func makeController(
        preference: any LiveActivityPreferenceReading = FixedTestLiveActivityPreference(isEnabled: true)
    ) -> LiveActivityController {
        LiveActivityController(preference: preference, liveActivityPermission: SilentAllowedPermission(), host: host)
    }

    private static func state(
        _ phase: DriveCheckActivityPhase,
        isStale: Bool = false
    ) -> DriveCheckActivityAttributes.ContentState {
        DriveCheckActivityAttributes.ContentState(
            phase: phase,
            regionTitle: "Kyiv",
            checkedAt: checkedAt,
            sourceLabel: "Ubilling",
            isStale: isStale
        )
    }

    /// Each reconcile reads the latest content when it runs, so a session reconcile still queued
    /// when content arrives would already act on that content. Settling keeps each step separate.
    private func openPhoneSession(on controller: LiveActivityController) async {
        controller.beginPhoneForegroundSession()
        await controller.settle()
    }

    private func show(_ phase: DriveCheckActivityPhase, isStale: Bool = false, on controller: LiveActivityController)
        async
    {
        let state = Self.state(phase, isStale: isStale)
        controller.update(
            phase: state.phase,
            regionTitle: state.regionTitle,
            checkedAt: state.checkedAt,
            sourceLabel: state.sourceLabel,
            isStale: state.isStale
        )
        await controller.settle()
    }

    @Test("REQ-SURF-009 an alert seen in a session requests exactly one activity with the latest content")
    func alarmInSessionRequestsOnce() async {
        let controller = makeController()
        await openPhoneSession(on: controller)

        await show(.alarm, on: controller)

        #expect(host.calls == [.request(id: 1, state: Self.state(.alarm), staleDate: Self.staleDate)])
    }

    @Test("REQ-SURF-009 new content for a running activity updates it, after the session too, without a second request")
    func newContentUpdatesRunningActivity() async {
        let controller = makeController()
        await openPhoneSession(on: controller)
        await show(.alarm, on: controller)
        controller.endPhoneForegroundSession()
        await controller.settle()

        await show(.alarm, isStale: true, on: controller)

        #expect(
            host.calls == [
                .request(id: 1, state: Self.state(.alarm), staleDate: Self.staleDate),
                // Leaving the session reconciles too and keeps the activity; with nothing new to
                // show it sends no update.
                .update(id: 1, state: Self.state(.alarm, isStale: true), staleDate: Self.staleDate),
            ])
    }

    @Test("REQ-SURF-009 content that equals what the activity already shows is not sent again")
    func identicalContentIsNotSentTwice() async {
        let controller = makeController()
        controller.beginPhoneForegroundSession()
        await show(.alarm, on: controller)
        await show(.alarm, on: controller)

        #expect(host.calls == [.request(id: 1, state: Self.state(.alarm), staleDate: Self.staleDate)])
    }

    @Test("REQ-SURF-009 a confirmed all-clear ends the activity at once")
    func allClearEndsActivity() async {
        let controller = makeController()
        await openPhoneSession(on: controller)
        await show(.alarm, on: controller)

        await show(.quiet, on: controller)

        #expect(host.calls.last == .end(id: 1, state: Self.state(.quiet), dismissal: .immediate))
        #expect(host.runningActivities().isEmpty)
    }

    @Test("REQ-SURF-009 an alert adopts the first surviving activity and ends the duplicates")
    func alarmAdoptsFirstSurvivor() async {
        host.addSurvivor()
        host.addSurvivor()
        let controller = makeController()

        await show(.alarm, on: controller)
        await show(.alarm, isStale: true, on: controller)

        #expect(
            host.calls == [
                .end(id: 2, state: nil, dismissal: .immediate),
                .update(id: 1, state: Self.state(.alarm), staleDate: Self.staleDate),
                .update(id: 1, state: Self.state(.alarm, isStale: true), staleDate: Self.staleDate),
            ])
    }

    @Test("REQ-SURF-009 a confirmed all-clear ends every surviving activity")
    func allClearEndsSurvivors() async {
        host.addSurvivor()
        host.addSurvivor()
        let controller = makeController()

        await show(.quiet, on: controller)

        #expect(
            host.calls == [
                .end(id: 1, state: nil, dismissal: .immediate),
                .end(id: 2, state: nil, dismissal: .immediate),
            ])
    }

    @Test("REQ-SURF-008 turning the driver's preference off ends the running activity")
    func preferenceOffEndsActivity() async {
        let preference = SwitchablePreference()
        let controller = makeController(preference: preference)
        await openPhoneSession(on: controller)
        await show(.alarm, on: controller)

        preference.turnOff()

        let ended = await eventually {
            host.calls.last == .end(id: 1, state: Self.state(.alarm), dismissal: .immediate)
        }
        #expect(ended)
    }

    @Test("REQ-SURF-009 a refused request leaves no activity, and the next alert content tries again")
    func refusedRequestIsRetried() async {
        let controller = makeController()
        await openPhoneSession(on: controller)
        host.failsRequests = true
        await show(.alarm, on: controller)
        #expect(host.calls.isEmpty)

        host.failsRequests = false
        await show(.alarm, on: controller)

        #expect(host.calls == [.request(id: 1, state: Self.state(.alarm), staleDate: Self.staleDate)])
    }

    @Test("An ended activity is never updated again: the next alert requests a new one")
    func alarmAfterEndAllRequestsNewActivity() async {
        let controller = makeController()
        await openPhoneSession(on: controller)
        await show(.alarm, on: controller)

        controller.endAll()
        await show(.alarm, on: controller)

        #expect(
            host.calls == [
                .request(id: 1, state: Self.state(.alarm), staleDate: Self.staleDate),
                .end(id: 1, state: Self.state(.alarm), dismissal: .immediate),
                .request(id: 2, state: Self.state(.alarm), staleDate: Self.staleDate),
            ])
    }
}

@MainActor
private final class SwitchablePreference: LiveActivityPreferenceReading {
    private(set) var isEnabled = true
    private let stream = AsyncStream<Void>.makeStream()

    func changes() -> AsyncStream<Void> {
        stream.stream
    }

    func turnOff() {
        isEnabled = false
        stream.continuation.yield()
    }
}
