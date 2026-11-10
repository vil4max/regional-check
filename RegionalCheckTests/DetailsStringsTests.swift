import Foundation
@testable import RegionalCheck
import Testing

/// Details strings (DETAILS-compact AC-4, AC-6): three languages, and each switch caption is one
/// short sentence.
struct DetailsStringsTests {
    private static let languages = ["en", "uk", "ru"]

    @Test("REQ-PUSH-007 Details headers and captions exist in en, uk and ru")
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

    @Test("REQ-PUSH-006 both switch captions are a single sentence, and the push one still names token and region")
    func captionsAreOneSentence() throws {
        let strings = try Self.catalog()
        for key in ["about.pro.liveActivity.caption", "details.allClear.caption"] {
            for language in Self.languages {
                let text = Self.value(strings, key, language) ?? ""
                let inner = text.trimmingCharacters(in: .whitespaces).dropLast()
                #expect(!inner.contains(". "), "\(key) in \(language) has more than one sentence: \(text)")
            }
        }
        let english = Self.value(strings, "details.allClear.caption", "en") ?? ""
        #expect(english.contains("token") && english.contains("region"))
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
}
