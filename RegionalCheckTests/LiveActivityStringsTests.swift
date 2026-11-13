import Testing

/// REQ-SURF-014 clause 6: every Live Activity string ships in en, ru and uk. The widget extension's
/// bundle is not reachable from the test host, so this reads the catalog it is built from.
struct LiveActivityStringsTests {
    private static let locales: Set = ["en", "ru", "uk"]

    @Test("REQ-SURF-014 every Live Activity string has en, ru and uk")
    func everyLiveActivityStringIsTranslated() throws {
        let catalog = try StringCatalog(path: StringCatalog.widgetsPath)
        let keys = catalog.values.keys.filter { $0.hasPrefix("liveActivity.") }
        #expect(keys.contains("liveActivity.started %@"))
        for key in keys {
            let missing = Self.locales.subtracting(catalog.values[key]?.keys ?? [:].keys)
            #expect(missing.isEmpty, "\(key) has no \(missing.sorted())")
        }
    }

    @Test("REQ-SURF-014 the start line wraps the system's relative time once, in each language")
    func startLineWrapsTheRelativeTime() throws {
        let values = try #require(try StringCatalog(path: StringCatalog.widgetsPath).values["liveActivity.started %@"])
        #expect(values == ["en": "Started %@", "ru": "Началась %@", "uk": "Почалася %@"])
    }
}
