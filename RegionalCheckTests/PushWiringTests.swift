import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The composition root's push wiring, split from `PushRegistrationTests` for the lint file limit.
extension PushRegistrationTests {
    @Test("REQ-PUSH-001 starting push registration shows the switch, syncs once, and is safe to call twice")
    func startingPushRegistrationWiresTheSwitch() async throws {
        let container = AppContainer.fixture(region: .kharkiv)
        let suite = "vil4max.RegionalCheck.push.wiring.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        // An earlier launch's opt-in and token, so the launch sync has something to send.
        let store = PushPreferenceStore(defaults: defaults)
        store.isEnabled = true
        store.token = "0a"
        let permission = FakePushPermission(current: .allowed, grants: true)
        let client = FakePushClient()
        container.pushRegistration = PushRegistrationController(
            regions: container.regions, permission: permission, registrar: FakeRegistrar(), client: client,
            store: store, locale: { Locale(identifier: "uk_UA") }, environment: .sandbox)
        #expect(container.detailsViewModel.allClearPush == nil)

        container.startPushRegistration()
        container.startPushRegistration()
        await container.pushRegistration.idle()

        #expect(container.detailsViewModel.allClearPush === container.pushRegistration)
        #expect(container.liveActivity.tokenSink === container.liveActivityPush)
        #expect(client.puts.map(\.region) == ["kharkiv"])
        #expect(permission.statusReads == 1, "a second start must not queue a second launch sync")
    }

    @Test("ALERT-push AC-9 the container wires Live Activity tokens at construction, with no scene")
    func liveActivityTokensAreWiredWithoutAScene() {
        let container = AppContainer.fixture(region: .kharkiv)

        #expect(container.liveActivity.tokenSink === container.liveActivityPush)
    }

    @Test("REQ-PUSH-001 a later launch with a stored opt-in follows a region change without asking again")
    func laterLaunchFollowsRegionWithoutDeleting() async {
        let suite = "vil4max.RegionalCheck.push.launch.\(UUID().uuidString)"
        let first = Rig(region: .kharkiv, suite: suite)
        await first.controller.setEnabled(true)
        await first.controller.didRegister(deviceToken: Data([0x05]))

        // A new process, as a CarPlay-only launch: nothing calls setEnabled or the phone foreground hook.
        let second = Rig(region: .kharkiv, permission: .allowed, suite: suite)
        second.controller.startObservingRegionChanges()
        second.regions.region = .poltava
        await second.controller.sync()

        #expect(second.client.deletes.isEmpty)
        #expect(second.client.puts.map(\.region) == ["poltava"])
        #expect(second.permission.requests == 0)
    }
}
