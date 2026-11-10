import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// ALERT-push AC-13..AC-15: pushes are calm by default; the driver may opt in to Time Sensitive
/// delivery, Details shows what iOS actually allows, and every label is Apple's own wording.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct UrgentPushTests {
    private func optedIn(timeSensitive: Bool = true) async -> Rig {
        let rig = Rig(region: .kharkiv)
        rig.permission.timeSensitive = timeSensitive
        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0x0A]))
        return rig
    }

    @Test("ALERT-push AC-13 urgent is sent only while the Time Sensitive switch is on, and left out otherwise")
    func urgentFollowsTheSwitch() async {
        let rig = await optedIn()
        #expect(rig.client.puts.last?.urgent == nil)
        #expect(rig.controller.isUrgent == false)

        await rig.controller.setUrgent(true)
        #expect(rig.client.puts.last?.urgent == true)

        await rig.controller.setUrgent(false)
        #expect(rig.client.puts.last?.urgent == nil)
        #expect(rig.client.puts.last == rig.registration(token: "0a", region: "kharkiv"))
    }

    @Test("ALERT-push AC-13 the Live Activity record is urgent only with the notice and Time Sensitive switches on")
    func liveActivityRecordFollowsUrgent() async {
        let rig = LiveActivityRig(region: .kharkiv)
        let store = PushPreferenceStore(defaults: rig.defaults)
        rig.registrar.liveActivitiesAllowedDidChange(true)
        rig.registrar.startTokenDidChange(Data([0x01]))
        await rig.registrar.idle()
        #expect(rig.client.puts.last?.urgent == nil)

        store.isUrgent = true
        rig.registrar.urgentDidChange()
        await rig.registrar.idle()
        #expect(rig.client.puts.last?.urgent == nil, "notices are off, so Time Sensitive does not apply")

        store.isEnabled = true
        rig.registrar.urgentDidChange()
        await rig.registrar.idle()
        #expect(rig.client.puts.last?.urgent == true)
    }

    @Test(
        "ALERT-push AC-14 the Time Sensitive Off row shows only with the switch on and iOS off, re-read on foreground")
    func timeSensitiveRowFollowsTheSystem() async {
        let rig = await optedIn(timeSensitive: false)
        #expect(rig.controller.showsTimeSensitiveOff == false, "the switch is off by default")

        await rig.controller.setUrgent(true)
        #expect(rig.controller.showsTimeSensitiveOff)

        rig.permission.timeSensitive = true
        await rig.controller.sceneDidBecomeActive()
        #expect(rig.controller.showsTimeSensitiveOff == false)
    }

    /// Through the built app's `.lproj` tables. Expected values: Apple's iOS 27.0.1 (24A446) strings,
    /// `NotificationsSettings.bundle` and `MobilePhone.app`, via applelocalization.com.
    @Test("ALERT-push AC-15 the switch, the rows and the button use Apple's own wording in en, uk and ru")
    func labelsAreApples() throws {
        let expected: [String: [String: String]] = [
            "details.push.timeSensitive": [
                "en": "Time Sensitive Notifications", "uk": "Термінові сповіщення", "ru": "Неотложные уведомления",
            ],
            "details.push.timeSensitive.caption": Self.timeSensitiveCaption,
            "details.push.allowNotifications": [
                "en": "Allow Notifications", "uk": "Дозволити сповіщення", "ru": "Допуск уведомлений",
            ],
            "details.push.off": ["en": "Off", "uk": "Вимкнено", "ru": "Выкл."],
            "location.access.open_settings": [
                "en": "Open Settings", "uk": "Відкрити Параметри", "ru": "Открыть Настройки",
            ],
        ]
        for (key, values) in expected {
            for (language, text) in values {
                let path = try #require(AppLocalization.bundle.path(forResource: language, ofType: "lproj"))
                let bundle = try #require(Bundle(path: path))
                #expect(bundle.localizedString(forKey: key, value: "MISSING", table: nil) == text, "\(key) \(language)")
            }
        }
    }

    private static let timeSensitiveCaption = [
        "en": [
            "Time Sensitive notifications are always delivered immediately",
            "and remain on the Lock Screen for an hour.",
        ].joined(separator: " "),
        "uk": [
            "Термінові сповіщення завжди доставляються миттєво",
            "й залишаються на замкненому екрані протягом години.",
        ].joined(separator: " "),
        "ru": [
            "Неотложные уведомления доставляются без промедления",
            "и остаются на заблокированном экране в течение часа.",
        ].joined(separator: " "),
    ]
}
