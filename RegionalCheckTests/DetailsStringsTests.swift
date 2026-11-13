import Foundation
@testable import RegionalCheck
import Testing

/// Details strings (DETAILS-compact AC-4, AC-6): three languages, and each switch caption is one
/// short sentence.
struct DetailsStringsTests {
    private static let languages = ["en", "uk", "ru"]

    @Test("DETAILS-compact AC-6 Details headers and captions exist in en, uk and ru")
    func detailsStringsAreLocalized() throws {
        let strings = try Self.catalog()
        for key in [
            "details.section.alerts", "details.section.about", "about.pro.liveActivity.caption",
            "details.allClear.caption",
        ] {
            for language in Self.languages {
                #expect(Self.value(strings, key, language)?.isEmpty == false, "\(key) missing for \(language)")
            }
        }
    }

    /// DETAILS-compact AC-4 as amended on 2026-11-10 (owner: "the device token is developer
    /// information"): the captions speak in the driver's terms; the data facts live in the privacy
    /// policy and the App Privacy answers, not on screen.
    @Test("DETAILS-compact AC-2 AC-4 UI-simplify AC-7 captions are one sentence with no token or server wording")
    func captionsAreOneSentence() throws {
        let strings = try Self.catalog()
        let developerWords = ["token", "server", "токен", "сервер"]
        for key in ["about.pro.liveActivity.caption", "details.allClear.caption"] {
            for language in Self.languages {
                let text = Self.value(strings, key, language) ?? ""
                let inner = text.trimmingCharacters(in: .whitespaces).dropLast()
                #expect(!inner.contains(". "), "\(key) in \(language) has more than one sentence: \(text)")
                for word in developerWords {
                    #expect(!text.lowercased().contains(word), "\(key) in \(language) names \(word): \(text)")
                }
            }
        }
    }

    /// The end-of-alert push is the all-clear, «отбой тревоги» / «відбій тривоги» (owner, 2026-11-11).
    @Test("ALERT-push AC-1 the notification footer names the all-clear by its own word")
    func notificationFooterNamesTheAllClear() throws {
        let strings = try Self.catalog()
        let words = ["en": "all-clear", "uk": "відбій тривоги", "ru": "отбое тревоги"]
        for (language, word) in words {
            let text = Self.value(strings, "details.allClear.caption", language) ?? ""
            #expect(text.contains(word), "\(language) footer must name the all-clear: \(text)")
        }
    }

    private static func catalog() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("RegionalCheck/Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return try #require(json?["strings"] as? [String: Any])
    }

    private static func value(_ strings: [String: Any], _ key: String, _ language: String) -> String? {
        let entry = strings[key] as? [String: Any]
        let localizations = entry?["localizations"] as? [String: Any]
        let unit = (localizations?[language] as? [String: Any])?["stringUnit"] as? [String: Any]
        return unit?["value"] as? String
    }

    /// Through the built app's `.lproj` tables, as the switch renders it.
    /// The title changed with UI-simplify (owner, 2026-11-10): named by what the driver gets, the
    /// notice at an alert's start and at the all-clear.
    @Test("ALERT-push AC-1 AC-8 UI-simplify AC-7 the one switch names alerts in the region, in en, uk and ru")
    func switchTitleCoversStartAndEnd() throws {
        let expected = [
            "en": "Alert Status Notifications",
            "uk": "Сповіщення про статус тривоги",
            "ru": "Уведомления о статусе тревоги",
        ]
        for (language, text) in expected {
            let path = try #require(AppLocalization.bundle.path(forResource: language, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            #expect(bundle.localizedString(forKey: "details.allClear.toggle", value: "MISSING", table: nil) == text)
        }
    }

    /// Labels Apple uses in iOS 27 take Apple's own translation (applelocalization.com, 27.0.1).
    @Test("UI-simplify AC-10 AC-12 Apple's labels carry Apple's iOS 27 translations")
    func appleLabelsUseAppleTranslations() throws {
        let strings = try Self.catalog()
        let expected: [String: [String: String]] = [
            "details.liveActivities": ["en": "Live Activities", "uk": "Дії наживо", "ru": "Эфир активности"],
            "details.section.notifications": ["en": "Notifications", "uk": "Сповіщення", "ru": "Уведомления"],
            "details.push.delivery.immediate": ["en": "Immediate", "uk": "Негайно", "ru": "Мгновенно"],
            "details.dataSource": ["en": "Data Source", "uk": "Джерело даних", "ru": "Источник данных"],
            "onboarding.continue": ["en": "Continue", "uk": "Продовжити", "ru": "Продолжить"],
            "tab.settings": ["en": "Settings", "uk": "Параметри", "ru": "Настройки"],
            "details.location": ["en": "Location", "uk": "Геопозиція", "ru": "Геопозиция"],
            "details.location.never": ["en": "Never", "uk": "Ніколи", "ru": "Никогда"],
        ]
        for (key, values) in expected {
            for (language, value) in values {
                #expect(Self.value(strings, key, language) == value, "\(key) in \(language)")
            }
        }
    }

    @Test("UI-simplify AC-10 every new Status, Details and onboarding string exists in en, uk and ru")
    func newStringsAreLocalized() throws {
        let strings = try Self.catalog()
        for key in [
            "details.liveActivities", "details.section.notifications", "details.dataSource",
            "onboarding.title", "onboarding.continue", "onboarding.row.carplay.title",
            "onboarding.row.location.title", "onboarding.row.free.title", "status.reason.nearby",
            "status.reason.since",
        ] {
            for language in Self.languages {
                #expect(Self.value(strings, key, language)?.isEmpty == false, "\(key) missing for \(language)")
            }
        }
    }

    @Test("MAP-native AC-8 the map data credit exists in every language")
    func mapDataCreditIsLocalized() throws {
        let strings = try Self.catalog()
        let expected = ["en": "Map Data", "uk": "Дані мапи", "ru": "Данные карты"]
        for (language, value) in expected {
            #expect(Self.value(strings, "details.mapSource", language) == value, "details.mapSource in \(language)")
        }
    }

    @Test("STATUS-reason AC-7 the reason lines carry their argument in every language, the removed rows are gone")
    func reasonStringsReplaceTheRows() throws {
        let strings = try Self.catalog()
        for key in ["status.reason.nearby", "status.reason.since"] {
            for language in Self.languages {
                #expect(Self.value(strings, key, language)?.contains("%@") == true, "\(key) in \(language)")
            }
        }
        for removed in [
            "status.nearby.title", "status.regions.count", "status.regions.title", "map.caption.updated",
            "map.fullscreen.loading",
        ] {
            #expect(strings[removed] == nil, "\(removed) still in the catalog")
        }
    }
}
