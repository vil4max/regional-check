import Foundation
@testable import RegionalCheck
import Testing

/// Resolves every key the Pro sheet, crown and Details row use through the built app's own
/// `.lproj` tables, so a key missing from the catalog or a typo at a call site both fail.
struct ProSheetLocalizationTests {
    private static let usedKeys = [
        "pro.crown.owned",
        "pro.sheet.buy %@",
        "pro.sheet.failed",
        "pro.sheet.free_note",
        "pro.sheet.icon_toggle",
        "pro.sheet.item.accent",
        "pro.sheet.item.crown",
        "pro.sheet.item.icon",
        "pro.sheet.owned",
        "pro.sheet.unavailable",
        "subscription.paywall.manage",
        "subscription.paywall.restore",
        "subscription.restore.success",
        "subscription.restore.empty",
        "subscription.restore.failed",
    ]

    @Test(
        "REQ-SURF-007 PRO-COSMETIC AC-10 every Pro string resolves in English, Ukrainian and Russian",
        arguments: ["en", "uk", "ru"]
    )
    func proStringsResolveInEveryShippedLocale(_ locale: String) throws {
        let path = try #require(AppLocalization.bundle.path(forResource: locale, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let missing = "\u{0}missing"

        for key in Self.usedKeys {
            let value = bundle.localizedString(forKey: key, value: missing, table: nil)
            #expect(value != missing && value != key, "\(key) has no \(locale) value")
        }
    }
}
