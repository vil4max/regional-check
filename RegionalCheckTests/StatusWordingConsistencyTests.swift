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

    private static let catalogPaths = [StringCatalog.mainPath, StringCatalog.widgetsPath, StringCatalog.kitPath]

    @Test("REQ-SURF-001 short-form status keys share one wording per locale across catalogs")
    func statusWordingMatchesAcrossCatalogs() throws {
        let catalogs = try Self.catalogPaths.map { try StringCatalog(path: $0) }
        let reference = try #require(catalogs.first)
        for key in Self.statusKeys {
            let expected = try #require(reference.values[key], "\(key) missing in \(reference.path)")
            #expect(!expected.isEmpty, "\(key) has no localizations in \(reference.path)")
            for catalog in catalogs.dropFirst() {
                #expect(catalog.values[key] == expected, "\(key) differs between \(reference.path) and \(catalog.path)")
            }
        }
    }

    @Test("REQ-SURF-001 short-form status keys use the approved en/ru/uk wording")
    func statusWordingUsesApprovedWording() throws {
        let approved: [String: [String: String]] = [
            "All Clear": ["en": "No Alert", "ru": "Тревоги нет", "uk": "Тривоги немає"],
            "Alert Active": ["en": "Alert", "ru": "Тревога", "uk": "Тривога"],
        ]
        for path in Self.catalogPaths {
            let catalog = try StringCatalog(path: path)
            for key in Self.statusKeys {
                guard let locales = catalog.values[key] else { continue }
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
                "en": "No Current Data", "ru": "Нет актуальных данных", "uk": "Немає актуальних даних",
            ],
        ]
        let main = try StringCatalog(path: StringCatalog.mainPath)
        for key in Self.fullFormKeys {
            let locales = try #require(main.values[key], "\(key) missing in \(main.path)")
            for locale in ["en", "ru", "uk"] {
                #expect(locales[locale] == approved[key]?[locale], "\(key)/\(locale)")
            }
        }
    }

    @Test("REQ-SURF-011 the Siri answer uses the app's own Stay Alert and No Current Data wording")
    func siriStatusWordingMatchesApp() throws {
        let keys = ["status.caution.title", "driver.status.no_current_data.title"]
        let app = try StringCatalog(path: StringCatalog.mainPath)
        let kit = try StringCatalog(path: StringCatalog.kitPath)
        for key in keys {
            let expected = try #require(app.values[key], "\(key) missing in \(app.path)")
            #expect(kit.values[key] == expected, "\(key) differs between \(app.path) and \(kit.path)")
        }
    }

    @Test("REQ-SURF-010 the widget's Stay Alert matches the app's wording")
    func widgetCautionWordingMatchesApp() throws {
        let key = "status.caution.title"
        let app = try StringCatalog(path: StringCatalog.mainPath)
        let widget = try StringCatalog(path: StringCatalog.widgetsPath)
        let expected = try #require(app.values[key])
        #expect(widget.values[key] == expected)
    }

    /// Keys deliberately excluded from `catalogsHaveNoMissingTranslations` (RD-11 acceptance:
    /// "no missing translations"): typographic glue with no meaning of its own, identical in
    /// every language.
    private static let translationExemptKeys: Set<String> = ["·"]

    @Test("RD-11 no key in any catalog is missing an en, ru or uk translation")
    func catalogsHaveNoMissingTranslations() throws {
        for path in Self.catalogPaths {
            let catalog = try StringCatalog(path: path)
            for (key, locales) in catalog.values where !Self.translationExemptKeys.contains(key) {
                for locale in ["en", "ru", "uk"] {
                    #expect(locales[locale]?.isEmpty == false, "\(key)/\(locale) missing in \(path)")
                }
            }
        }
    }
}
