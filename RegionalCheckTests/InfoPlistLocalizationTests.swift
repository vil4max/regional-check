import Foundation
import Testing

/// The system location prompt shows `NSLocationWhenInUseUsageDescription`, which iOS localizes
/// from `InfoPlist.xcstrings`, not from the app's main catalog. Without it the prompt was English
/// for Ukrainian and Russian users next to a fully translated app.
struct InfoPlistLocalizationTests {
    private static let key = "NSLocationWhenInUseUsageDescription"

    private func purposeString(for localization: String) -> String? {
        guard
            let path = Bundle.main.path(
                forResource: "InfoPlist",
                ofType: "strings",
                inDirectory: nil,
                forLocalization: localization
            ),
            let table = NSDictionary(contentsOfFile: path) as? [String: String]
        else {
            return nil
        }
        return table[Self.key]
    }

    @Test("The location purpose string ships in every language the app supports", arguments: ["uk", "ru"])
    func locationPurposeStringIsLocalized(localization: String) throws {
        let english = try #require(Bundle.main.object(forInfoDictionaryKey: Self.key) as? String)
        let localized = try #require(purposeString(for: localization))

        #expect(!localized.isEmpty)
        #expect(localized != english)
    }
}
