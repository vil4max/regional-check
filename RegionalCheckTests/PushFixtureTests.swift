import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The pieces previews and test containers rely on: the push fixture reports what it was given and
/// reaches no server, and the offline Live Activity client accepts and drops every request.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct PushFixtureTests {
    @Test("ALERT-push AC-14 the push fixture keeps iOS's state through a foreground and stays on")
    func fixtureKeepsItsSystemStateThroughAForeground() async {
        let system = NotificationSystemSettings(isAllowed: true, isTimeSensitiveOn: false, isScheduledSummaryOn: true)
        let controller = PushRegistrationController.fixture(
            regions: FakePushRegions(region: .kharkiv), system: system,
            defaultsSuite: "vil4max.RegionalCheck.test.pushFixture.\(UUID().uuidString)")
        #expect(controller.isSwitchOn)

        await controller.sceneDidBecomeActive()
        await controller.didRegister(deviceToken: Data([0x0A]))

        #expect(controller.systemSettings == system)
        #expect(controller.isSwitchOn)
        #expect(await FixturePushPermission(system: system).request())
    }

    @Test("ALERT-push AC-2 test containers' Live Activity client accepts and drops every request")
    func offlineClientDropsRequests() async throws {
        let client = OfflineLiveActivityPushClient()
        try await client.put(
            LiveActivityPushRecord(startToken: "01", region: "kharkiv", env: "sandbox", lang: "uk", activityToken: nil))
        try await client.delete(startToken: "01")
    }

    @Test("ALERT-push AC-2 sync sends the record once, and an unchanged record is not sent again")
    func syncSendsOnce() async {
        let rig = LiveActivityRig(region: .kharkiv)
        rig.registrar.liveActivitiesAllowedDidChange(true)
        rig.registrar.startTokenDidChange(Data([0x01]))

        await rig.registrar.sync()
        await rig.registrar.sync()

        #expect(rig.client.puts == [rig.record(start: "01", activity: nil)])
    }
}
