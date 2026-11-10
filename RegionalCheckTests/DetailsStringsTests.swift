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

    @Test("DETAILS-compact AC-2 AC-4 REQ-PUSH-006 captions are one sentence and name token and region")
    func captionsAreOneSentence() throws {
        let strings = try Self.catalog()
        for key in ["about.pro.liveActivity.caption", "details.allClear.caption"] {
            for language in Self.languages {
                let text = Self.value(strings, key, language) ?? ""
                let inner = text.trimmingCharacters(in: .whitespaces).dropLast()
                #expect(!inner.contains(". "), "\(key) in \(language) has more than one sentence: \(text)")
            }
        }
        let words = ["en": ("token", "region"), "uk": ("токен", "регіон"), "ru": ("токен", "регион")]
        for (language, pair) in words {
            let text = (Self.value(strings, "details.allClear.caption", language) ?? "").lowercased()
            #expect(
                text.contains(pair.0) && text.contains(pair.1), "\(language) caption must name the token and the region"
            )
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
    /// The title changed with UI-simplify (owner, 2026-11-10): still alerts in the region, as a
    /// Settings-style name.
    @Test("ALERT-push AC-1 AC-8 UI-simplify AC-7 the one switch names alerts in the region, in en, uk and ru")
    func switchTitleCoversStartAndEnd() throws {
        let expected = [
            "en": "Alerts in My Region",
            "uk": "Тривоги в моєму регіоні",
            "ru": "Тревоги в моём регионе",
        ]
        for (language, text) in expected {
            let path = try #require(AppLocalization.bundle.path(forResource: language, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            #expect(bundle.localizedString(forKey: "details.allClear.toggle", value: "MISSING", table: nil) == text)
        }
    }

    /// Labels Apple uses in iOS 27 take Apple's own translation (applelocalization.com, 27.0.1).
    @Test("UI-simplify AC-10 Apple's labels carry Apple's iOS 27 translations")
    func appleLabelsUseAppleTranslations() throws {
        let strings = try Self.catalog()
        let expected: [String: [String: String]] = [
            "details.liveActivities": ["en": "Live Activities", "uk": "Дії наживо", "ru": "Эфир активности"],
            "details.section.notifications": ["en": "Notifications", "uk": "Сповіщення", "ru": "Уведомления"],
            "details.push.delivery.immediate": ["en": "Immediate", "uk": "Негайно", "ru": "Мгновенно"],
            "details.dataSource": ["en": "Data Source", "uk": "Джерело даних", "ru": "Источник данных"],
            "onboarding.continue": ["en": "Continue", "uk": "Продовжити", "ru": "Продолжить"],
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
            "onboarding.row.location.title", "onboarding.row.free.title", "status.nearby.title",
            "status.regions.title", "status.regions.count",
        ] {
            for language in Self.languages {
                #expect(Self.value(strings, key, language)?.isEmpty == false, "\(key) missing for \(language)")
            }
        }
    }
}
