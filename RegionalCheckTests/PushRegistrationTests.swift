import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The all-clear push opt-in: what the device tells the server, and when.
@MainActor
struct PushRegistrationTests {
    // MARK: - Registration (REQ-PUSH-001)

    @Test("REQ-PUSH-001 opting in registers the token and the current region once")
    func optInRegistersTokenAndRegion() async {
        let rig = Rig(region: .kharkiv)

        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0xAB, 0x01]))

        #expect(rig.client.puts == [rig.registration(token: "ab01", region: "kharkiv")])
        #expect(rig.registrar.calls == 1)
        #expect(rig.controller.isSwitchOn)
    }

    @Test("REQ-PUSH-001 a region change registers again, and an unchanged region does not")
    func regionChangeRegistersAgain() async {
        let rig = Rig(region: .kharkiv)
        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0x01]))

        await rig.controller.sync()
        #expect(rig.client.puts.count == 1)

        rig.regions.region = .odesa
        await rig.controller.sync()
        #expect(rig.client.puts.map(\.region) == ["kharkiv", "odesa"])
    }

    @Test("REQ-PUSH-004 the Kyiv fallback of a first launch is never registered")
    func fallbackRegionIsNotRegistered() async {
        let rig = Rig(region: nil)
        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0x01]))

        #expect(rig.client.puts.isEmpty)

        rig.regions.region = .kyivCity
        await rig.controller.sync()
        #expect(rig.client.puts.map(\.region) == ["kyivCity"])
    }

    // MARK: - Switching off and permission (REQ-PUSH-003, REQ-PUSH-005)

    @Test("REQ-PUSH-003 switching off sends one delete and the next sync sends nothing")
    func switchingOffDeletesOnce() async {
        let rig = Rig(region: .kharkiv)
        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0x07]))

        await rig.controller.setEnabled(false)
        await rig.controller.sync()

        #expect(rig.client.deletes == ["07"])
        #expect(rig.client.puts.count == 1)
        #expect(!rig.controller.isSwitchOn)
    }

    @Test("REQ-PUSH-003 a delete that fails offline is retried on the next foreground")
    func failedDeleteIsRetried() async {
        let rig = Rig(region: .kharkiv)
        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0x07]))
        rig.client.fails = true

        await rig.controller.setEnabled(false)
        #expect(rig.client.deletes.isEmpty)

        rig.client.fails = false
        await rig.controller.sceneDidBecomeActive()
        #expect(rig.client.deletes == ["07"])
    }

    @Test("REQ-PUSH-005 a refused permission leaves the switch off and registers nothing")
    func deniedPermissionLeavesSwitchOff() async {
        let rig = Rig(region: .kharkiv, permission: .notDetermined, grants: false)

        await rig.controller.setEnabled(true)

        #expect(!rig.controller.isSwitchOn)
        #expect(rig.controller.isBlockedBySystem)
        #expect(rig.registrar.calls == 0)
        #expect(rig.client.puts.isEmpty)
    }

    @Test("REQ-PUSH-005 notifications revoked in Settings turn the switch off and delete the token")
    func revokedPermissionDeletesToken() async {
        let rig = Rig(region: .kharkiv)
        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0x09]))

        rig.permission.current = .denied
        await rig.controller.sceneDidBecomeActive()

        #expect(!rig.controller.isSwitchOn)
        #expect(rig.client.deletes == ["09"])
    }

    // MARK: - What leaves the device (REQ-PUSH-006)

    @Test("REQ-PUSH-006 the request body carries exactly token, region, env and lang")
    func bodyCarriesOnlyTheFourFields() throws {
        let body = PushRegistration(token: "ab", region: "kharkiv", env: "sandbox", lang: "uk")

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: String]

        #expect(Set(json?.keys ?? [:].keys) == ["token", "region", "env", "lang"])
    }

    @Test("REQ-PUSH-006 the text language is en, uk or ru, and English for any other")
    func languageFallsBackToEnglish() {
        #expect(PushRegistration.language(for: Locale(identifier: "uk_UA")) == "uk")
        #expect(PushRegistration.language(for: Locale(identifier: "ru")) == "ru")
        #expect(PushRegistration.language(for: Locale(identifier: "de_DE")) == "en")
    }

    @Test("REQ-PUSH-007 every string of the all-clear switch exists in en, uk and ru")
    func switchStringsAreLocalizedEverywhere() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("RegionalCheck/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any]
        let strings = try #require(json?["strings"] as? [String: Any])

        for key in [
            "about.section.allClear", "details.allClear.toggle", "details.allClear.caption",
            "details.allClear.systemOff",
        ] {
            let entry = try #require(strings[key] as? [String: Any], "\(key) missing from the catalog")
            let localizations = try #require(entry["localizations"] as? [String: Any])
            for locale in ["en", "uk", "ru"] {
                let unit = (localizations[locale] as? [String: Any])?["stringUnit"] as? [String: Any]
                #expect((unit?["value"] as? String)?.isEmpty == false, "\(key) missing for \(locale)")
            }
        }
    }

    @Test("REQ-PUSH-004 a first launch without a stored region has no eligible region; a stored one does")
    func selectionIsEligibleOnlyWithAStoredRegion() throws {
        let suite = "PushRegistrationTests.selection.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults, legacyDefaults: defaults))

        #expect(RegionSelection(store: store).pushEligibleRegion == nil)

        store.save(.kharkiv)
        #expect(RegionSelection(store: store).pushEligibleRegion == .kharkiv)
    }
}

// MARK: - Fakes

@MainActor
private final class Rig {
    let regions: FakePushRegions
    let permission: FakePushPermission
    let registrar = FakeRegistrar()
    let client = FakePushClient()
    let controller: PushRegistrationController

    init(region: AlertRegion?, permission status: PushPermissionStatus = .allowed, grants: Bool = true) {
        regions = FakePushRegions(region: region)
        permission = FakePushPermission(current: status, grants: grants)
        let suite = "vil4max.RegionalCheck.push.\(UUID().uuidString)"
        controller = PushRegistrationController(
            regions: regions,
            permission: permission,
            registrar: registrar,
            client: client,
            store: PushPreferenceStore(defaults: UserDefaults(suiteName: suite) ?? .standard),
            locale: { Locale(identifier: "uk_UA") },
            environment: .sandbox
        )
    }

    func registration(token: String, region: String) -> PushRegistration {
        PushRegistration(token: token, region: region, env: "sandbox", lang: "uk")
    }
}

@MainActor
private final class FakePushRegions: PushRegionProviding {
    var region: AlertRegion?
    init(region: AlertRegion?) { self.region = region }
    var pushEligibleRegion: AlertRegion? { region }
}

private final class FakePushPermission: PushPermissionProviding, @unchecked Sendable {
    var current: PushPermissionStatus
    let grants: Bool
    init(current: PushPermissionStatus, grants: Bool) {
        self.current = current
        self.grants = grants
    }
    func status() async -> PushPermissionStatus { current }
    func request() async -> Bool {
        current = grants ? .allowed : .denied
        return grants
    }
}

@MainActor
private final class FakeRegistrar: RemoteNotificationRegistering {
    private(set) var calls = 0
    func registerForRemoteNotifications() { calls += 1 }
}

private final class FakePushClient: PushRegistrationSending, @unchecked Sendable {
    private(set) var puts: [PushRegistration] = []
    private(set) var deletes: [String] = []
    var fails = false

    func put(_ registration: PushRegistration) async throws {
        if fails { throw URLError(.notConnectedToInternet) }
        puts.append(registration)
    }

    func delete(token: String) async throws {
        if fails { throw URLError(.notConnectedToInternet) }
        deletes.append(token)
    }
}
