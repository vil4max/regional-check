import Foundation
import Testing

/// Reads the source catalog rather than the app bundle, for the reason
/// `StatusWordingConsistencyTests` does: the string is a shipped wording contract, and the
/// catalog is where it can be checked in every locale at once.
struct DetailsDisclaimerTests {
    private static let disclaimerKey = "about.disclaimer"
    private static let shippedLocales = ["en", "ru", "uk"]

    @Test("REQ-PROVIDER-003 Details calls the alert data informational, in the provider's terms")
    func disclaimerUsesTheApprovedEnglish() throws {
        let values = try Self.disclaimerValues()

        #expect(values["en"] == "Alert data is informational only. Do not rely on it for critical decisions.")
    }

    @Test("REQ-PROVIDER-003 the disclaimer reaches every shipped locale, not only English")
    func disclaimerIsLocalizedEverywhere() throws {
        let values = try Self.disclaimerValues()

        for locale in Self.shippedLocales {
            let value = try #require(values[locale], "\(Self.disclaimerKey) missing for \(locale)")
            #expect(!value.isEmpty, "\(Self.disclaimerKey) is empty for \(locale)")
        }
    }

    /// `[locale: value]` for the disclaimer key.
    private static func disclaimerValues() throws -> [String: String] {
        let catalog = try StringCatalog(path: StringCatalog.mainPath)
        return try #require(catalog.values[disclaimerKey], "\(disclaimerKey) missing from the catalog")
    }
}
