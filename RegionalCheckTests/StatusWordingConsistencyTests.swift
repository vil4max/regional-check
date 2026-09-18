import Foundation
import Testing

/// Reads source catalogs because the widget extension and DriveCheckKit bundles
/// are not reachable from the app test host.
struct StatusWordingConsistencyTests {
    /// Short forms (REQ-SURF-001): pills, widgets, Live Activity, Dynamic Island, Control Center —
    /// shared verbatim by every catalog that carries a status word at all.
    private static let statusKeys = ["All Clear", "Alert Active"]

    /// Full forms (REQ-SURF-001): iPhone and CarPlay titles only. Not duplicated into the widget
    /// or DriveCheckKit catalogs — neither surface shows a full-form status title — so these are
    /// checked for correct wording within the main catalog, not for cross-catalog equality.
    private static let fullFormKeys = ["driver.status.full.alarm", "driver.status.no_current_data.title"]

    private static let mainCatalogPath = "RegionalCheck/Resources/Localizable.xcstrings"

    private static let catalogPaths = [
        mainCatalogPath,
        "RegionalCheckWidgets/Localizable.xcstrings",
        "Packages/DriveCheckKit/Sources/DriveCheckKit/Resources/Localizable.xcstrings"
    ]

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("REQ-SURF-001 short-form status keys share one wording per locale across catalogs")
    func statusWordingMatchesAcrossCatalogs() throws {
        let catalogs = try Self.catalogPaths.map { path in
            try (path, Self.values(for: Self.statusKeys, in: Self.repositoryRoot.appendingPathComponent(path)))
        }
        let (referencePath, reference) = try #require(catalogs.first)
        for key in Self.statusKeys {
            let expected = try #require(reference[key], "\(key) missing in \(referencePath)")
            #expect(!expected.isEmpty, "\(key) has no localizations in \(referencePath)")
            for (path, values) in catalogs.dropFirst() {
                #expect(values[key] == expected, "\(key) differs between \(referencePath) and \(path)")
            }
        }
    }

    @Test("REQ-SURF-001 short-form status keys use the approved en/ru/uk wording")
    func statusWordingUsesApprovedWording() throws {
        let approved: [String: [String: String]] = [
            "All Clear": ["en": "No Alert", "ru": "Тревоги нет", "uk": "Тривоги немає"],
            "Alert Active": ["en": "Alert", "ru": "Тревога", "uk": "Тривога"]
        ]
        for path in Self.catalogPaths {
            let values = try Self.values(for: Self.statusKeys, in: Self.repositoryRoot.appendingPathComponent(path))
            for key in Self.statusKeys {
                guard let locales = values[key] else { continue }
                for (locale, expected) in approved[key] ?? [:] where locales[locale] != nil {
                    #expect(locales[locale] == expected, "\(key)/\(locale) in \(path)")
                }
            }
        }
    }

    @Test("REQ-SURF-001 full-form status titles are translated en/ru/uk with the approved wording")
    func fullFormStatusTitlesAreApproved() throws {
        let approved: [String: [String: String]] = [
            "driver.status.full.alarm": ["en": "Air Raid Alert", "ru": "Воздушная тревога", "uk": "Повітряна тривога"],
            "driver.status.no_current_data.title": [
                "en": "No Current Data", "ru": "Нет актуальных данных", "uk": "Немає актуальних даних"
            ]
        ]
        let values = try Self.values(
            for: Self.fullFormKeys,
            in: Self.repositoryRoot.appendingPathComponent(Self.mainCatalogPath)
        )
        for key in Self.fullFormKeys {
            let locales = try #require(values[key], "\(key) missing in \(Self.mainCatalogPath)")
            for locale in ["en", "ru", "uk"] {
                #expect(locales[locale] == approved[key]?[locale], "\(key)/\(locale)")
            }
        }
    }

    /// Keys deliberately excluded from `catalogsHaveNoMissingTranslations` (RD-11 acceptance:
    /// "no missing translations"): typographic glue with no meaning of its own, identical in
    /// every language.
    private static let translationExemptKeys: Set<String> = ["·"]

    @Test("RD-11 no key in any catalog is missing an en, ru or uk translation")
    func catalogsHaveNoMissingTranslations() throws {
        for path in Self.catalogPaths {
            let data = try Data(contentsOf: Self.repositoryRoot.appendingPathComponent(path))
            let catalog = try JSONDecoder().decode(Catalog.self, from: data)
            for (key, entry) in catalog.strings where !Self.translationExemptKeys.contains(key) {
                let locales = entry.localizations ?? [:]
                for locale in ["en", "ru", "uk"] {
                    let value = locales[locale]?.stringUnit?.value
                    #expect(value?.isEmpty == false, "\(key)/\(locale) missing in \(path)")
                }
            }
        }
    }

    /// Returns `[key: [locale: value]]` for the given keys.
    private static func values(for keys: [String], in url: URL) throws -> [String: [String: String]] {
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        var result: [String: [String: String]] = [:]
        for key in keys {
            guard let entry = catalog.strings[key] else { continue }
            result[key] = (entry.localizations ?? [:]).compactMapValues { $0.stringUnit?.value }
        }
        return result
    }

    private struct Catalog: Decodable {
        let strings: [String: Entry]
    }

    private struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    private struct Localization: Decodable {
        let stringUnit: StringUnit?
    }

    private struct StringUnit: Decodable {
        let value: String
    }
}
