import CoreLocation
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
            "details.section.alerts", "details.allClear.toggle", "details.allClear.caption",
            "details.push.allowNotifications", "details.push.off", "details.push.on",
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

final class ClockBox: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1_000_000)
}

@MainActor
final class Rig {
    let regions: FakePushRegions
    let permission: FakePushPermission
    let registrar = FakeRegistrar()
    let client = FakePushClient()
    let controller: PushRegistrationController

    let clockBox = ClockBox()
    var clock: Date {
        get { clockBox.now }
        set { clockBox.now = newValue }
    }

    init(
        region: AlertRegion?, permission status: PushPermissionStatus = .allowed, grants: Bool = true,
        suite: String = "vil4max.RegionalCheck.push.\(UUID().uuidString)"
    ) {
        regions = FakePushRegions(region: region)
        permission = FakePushPermission(current: status, grants: grants)
        controller = PushRegistrationController(
            regions: regions,
            permission: permission,
            registrar: registrar,
            client: client,
            store: PushPreferenceStore(defaults: UserDefaults(suiteName: suite) ?? .standard),
            locale: { Locale(identifier: "uk_UA") },
            environment: .sandbox,
            now: { [clockBox] in clockBox.now }
        )
    }

    func registration(token: String, region: String) -> PushRegistration {
        PushRegistration(token: token, region: region, env: "sandbox", lang: "uk")
    }
}

@MainActor
final class FakePushRegions: PushRegionProviding {
    var region: AlertRegion?
    init(region: AlertRegion?) { self.region = region }
    var pushEligibleRegion: AlertRegion? { region }
}

final class FakePushPermission: PushPermissionProviding, @unchecked Sendable {
    var current: PushPermissionStatus
    let grants: Bool
    init(current: PushPermissionStatus, grants: Bool) {
        self.current = current
        self.grants = grants
    }
    private(set) var statusReads = 0
    func status() async -> PushPermissionStatus {
        statusReads += 1
        return current
    }
    var system = NotificationSystemSettings(isAllowed: true, isTimeSensitiveOn: false, isScheduledSummaryOn: false)
    private(set) var systemReads = 0
    func systemSettings() async -> NotificationSystemSettings {
        systemReads += 1
        return system
    }
    private(set) var requests = 0
    func request() async -> Bool {
        requests += 1
        current = grants ? .allowed : .denied
        return grants
    }
}

@MainActor
final class FakeRegistrar: RemoteNotificationRegistering {
    private(set) var calls = 0
    func registerForRemoteNotifications() { calls += 1 }
}

final class FakePushClient: PushRegistrationSending, @unchecked Sendable {
    private(set) var puts: [PushRegistration] = []
    private(set) var deletes: [String] = []
    var fails = false
    /// When set, the next `put` waits until `releasePut()` so a test can act while a request is in flight.
    var holdsPuts = false
    private var held: CheckedContinuation<Void, Never>?
    var isHoldingPut: Bool { held != nil }

    func releasePut() {
        held?.resume()
        held = nil
    }

    func put(_ registration: PushRegistration) async throws {
        if holdsPuts {
            await withCheckedContinuation { held = $0 }
        }
        if fails { throw URLError(.notConnectedToInternet) }
        puts.append(registration)
    }

    func delete(token: String) async throws {
        if fails { throw URLError(.notConnectedToInternet) }
        deletes.append(token)
    }
}

// MARK: - Review cases

extension PushRegistrationTests {
    @Test("REQ-PUSH-001 the registration is refreshed weekly, and not before")
    func registrationIsRefreshedWeekly() async {
        let rig = Rig(region: .kharkiv)
        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0x01]))

        rig.clock.addTimeInterval(6 * 24 * 3600)
        await rig.controller.sync()
        #expect(rig.client.puts.count == 1)

        rig.clock.addTimeInterval(2 * 24 * 3600)
        await rig.controller.sync()
        #expect(rig.client.puts.count == 2)
    }

    @Test("REQ-PUSH-003 switching off while a registration is in flight still deletes the token")
    func switchingOffDuringARequestStillDeletes() async {
        let rig = Rig(region: .kharkiv)
        await rig.controller.setEnabled(true)
        rig.client.holdsPuts = true
        let registering = Task { await rig.controller.didRegister(deviceToken: Data([0x01])) }
        for _ in 0..<1000 where !rig.client.isHoldingPut { await Task.yield() }
        #expect(rig.client.isHoldingPut)

        let switchingOff = Task { await rig.controller.setEnabled(false) }
        await Task.yield()
        rig.client.holdsPuts = false
        rig.client.releasePut()
        await registering.value
        await switchingOff.value

        #expect(rig.client.deletes == ["01"])
        #expect(rig.client.puts.count == 1)
    }

    @Test("REQ-PUSH-003 a refused or switched-off notice never asks iOS for permission again")
    func permissionIsRequestedOnlyAtOptIn() async {
        let rig = Rig(region: .kharkiv, permission: .notDetermined, grants: false)

        await rig.controller.setEnabled(true)
        await rig.controller.sceneDidBecomeActive()
        await rig.controller.setEnabled(false)
        await rig.controller.sceneDidBecomeActive()

        #expect(rig.permission.requests == 1)
    }

    @Test("REQ-PUSH-004 a first launch whose location finds no address or no known region stays unregistered")
    func unresolvedLocationDoesNotConfirmTheFallback() async throws {
        let (store, cleanup) = try Self.emptyStore()
        defer { cleanup() }
        let geocoder = AddressGeocoder(address: nil)
        // A clock the test advances: the tracker's geocode throttle (60 s, 5 km) otherwise parks the second fix.
        let clock = ClockBox()
        let selection = RegionSelection(
            store: store, geocoder: geocoder, now: { clock.now }, sleep: { _ in })

        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52))
        await selection.settled()
        #expect(selection.pushEligibleRegion == nil)

        clock.now.addTimeInterval(120)
        geocoder.address = GeocodedAddress(countryCode: "UA", cityName: nil, administrativeAreaName: nil)
        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 49.99, longitude: 36.23))
        await selection.settled()
        #expect(selection.pushEligibleRegion == nil)
    }

    @Test("REQ-PUSH-004 a region committed by location becomes eligible")
    func committedRegionBecomesEligible() async throws {
        let (store, cleanup) = try Self.emptyStore()
        defer { cleanup() }
        let geocoder = AddressGeocoder(
            address: GeocodedAddress(countryCode: "UA", cityName: "Kharkiv", administrativeAreaName: "Kharkiv Oblast"))
        let selection = RegionSelection(store: store, geocoder: geocoder)

        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 49.99, longitude: 36.23))
        await selection.settled()

        #expect(selection.pushEligibleRegion == selection.selectedRegion)
        #expect(selection.pushEligibleRegion != nil)
    }

    private static func emptyStore() throws -> (RegionStore, () -> Void) {
        let suite = "PushRegistrationTests.geo.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults, legacyDefaults: defaults))
        return (store, { defaults.removePersistentDomain(forName: suite) })
    }
}

private final class AddressGeocoder: ReverseGeocoding, @unchecked Sendable {
    var address: GeocodedAddress?
    init(address: GeocodedAddress?) { self.address = address }
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedAddress? { address }
}
