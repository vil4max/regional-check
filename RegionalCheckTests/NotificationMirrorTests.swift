import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// ALERT-push AC-13..AC-15: the system decides urgency, Details only mirrors iOS's notification
/// settings for the app, and every row speaks Apple's own words.
@Suite(.timeLimit(.minutes(1)))
@MainActor
struct NotificationMirrorTests {
    @Test("ALERT-push AC-14 the rows mirror iOS's settings and are read again on every foreground")
    func rowsFollowTheSystem() async {
        let rig = Rig(region: .kharkiv)
        rig.permission.system = NotificationSystemSettings(
            isAllowed: true, isTimeSensitiveOn: false, isScheduledSummaryOn: true)
        await rig.controller.sceneDidBecomeActive()
        #expect(rig.controller.systemSettings == rig.permission.system)

        rig.permission.system = NotificationSystemSettings(
            isAllowed: false, isTimeSensitiveOn: true, isScheduledSummaryOn: false)
        await rig.controller.sceneDidBecomeActive()
        #expect(rig.controller.systemSettings == rig.permission.system)
    }

    @Test("ALERT-push AC-13 no request carries an urgency field: the iOS setting decides")
    func requestsCarryNoUrgency() throws {
        let registration = PushRegistration(token: "0a", region: "kharkiv", env: "sandbox", lang: "uk")
        let record = LiveActivityPushRecord(
            startToken: "01", region: "kharkiv", env: "sandbox", lang: "uk", activityToken: "ab")

        let registrationKeys = try Self.keys(of: registration)
        let recordKeys = try Self.keys(of: record)

        #expect(registrationKeys == ["token", "region", "env", "lang"])
        #expect(recordKeys == ["startToken", "region", "env", "lang", "activityToken"])
    }

    /// Through the built app's `.lproj` tables. Expected values: Apple's iOS 27.0.1 (24A446)
    /// `NotificationsSettings.bundle` strings via applelocalization.com, and "Open Settings" from
    /// `MobilePhone.app`.
    @Test(
        "ALERT-push AC-15 UI-simplify AC-7 the rows, their values and the button use Apple's wording in en, uk, ru"
    )
    func labelsAreApples() throws {
        let expected: [String: [String: String]] = [
            "details.push.allowNotifications": [
                "en": "Allow Notifications", "uk": "Дозволити сповіщення", "ru": "Допуск уведомлений",
            ],
            "details.push.timeSensitive": [
                "en": "Time Sensitive Notifications", "uk": "Термінові сповіщення", "ru": "Неотложные уведомления",
            ],
            "details.push.delivery": [
                "en": "Notification Delivery", "uk": "Доставка сповіщень", "ru": "Доставка уведомлений",
            ],
            // UI-simplify AC-7 (owner, 2026-11-10): the shorter value, Apple's `IMMEDIATE`.
            "details.push.delivery.immediate": ["en": "Immediate", "uk": "Негайно", "ru": "Мгновенно"],
            "details.push.delivery.scheduled": [
                "en": "Scheduled Summary", "uk": "Звіт за розкладом", "ru": "Сводка по расписанию",
            ],
            "details.push.on": ["en": "On", "uk": "Увімкнено", "ru": "Вкл."],
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

    private static func keys(of value: some Encodable) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        return Set(try #require(object).keys)
    }
}
