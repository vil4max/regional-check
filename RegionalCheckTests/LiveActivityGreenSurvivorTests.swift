import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// REQ-SURF-009, ALERT-push AC-9: the green all-clear stays on screen for 5 minutes after it
/// ended, and a new process still finds it listed. It describes a finished alert, so a new alarm
/// must not adopt it: seen on the simulator on 2026-11-13, the green "All clear" stayed and no red
/// activity started until the green one was dismissed.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct LiveActivityGreenSurvivorTests {
    private static let checkedAt = Date(timeIntervalSince1970: 1_789_555_260)
    private let host = FixtureLiveActivityHost()

    private func makeController() -> LiveActivityController {
        LiveActivityController(
            preference: FixedTestLiveActivityPreference(isEnabled: true),
            liveActivityPermission: SilentAllowedPermission(),
            host: host
        )
    }

    @Test("REQ-SURF-009 an alarm ends a green all-clear left by the last process and starts its own")
    func alarmReplacesTheGreenSurvivor() async {
        let green = host.addSurvivor(phase: .quiet)
        let controller = makeController()
        controller.beginPhoneForegroundSession()

        controller.update(phase: .alarm, regionTitle: "Kharkiv", checkedAt: Self.checkedAt, sourceLabel: "Ubilling")
        await controller.settle()

        let ended = host.calls.contains { if case .end(green, _, .immediate) = $0 { true } else { false } }
        let requested = host.calls.contains { if case .request = $0 { true } else { false } }
        #expect(ended)
        #expect(requested)
        #expect(!host.calls.contains { if case .update(green, _, _) = $0 { true } else { false } })
    }

    @Test("REQ-SURF-009 an alarm still adopts a red survivor instead of requesting a second one")
    func alarmStillAdoptsARedSurvivor() async {
        let red = host.addSurvivor(phase: .alarm)
        let controller = makeController()
        controller.beginPhoneForegroundSession()

        controller.update(phase: .alarm, regionTitle: "Kharkiv", checkedAt: Self.checkedAt, sourceLabel: "Ubilling")
        await controller.settle()

        #expect(host.calls.contains { if case .update(red, _, _) = $0 { true } else { false } })
        #expect(!host.calls.contains { if case .request = $0 { true } else { false } })
    }
}
