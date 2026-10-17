import Foundation
@testable import RegionalCheck
import Testing

/// The alert section header of the region list is one localized format with the count, read
/// through the built app's own `.lproj` tables, so it keeps the text the two concatenated `Text`
/// values used to show before iOS 26 deprecated `Text`'s `+`.
struct RegionListLocalizationTests {
    @Test(
        "DUO AC-2 the alert section header reads the section name and the count in every shipped locale",
        arguments: [
            ("en", "Alert Active · 3"),
            ("uk", "Тривога · 3"),
            ("ru", "Тревога · 3"),
        ]
    )
    func alertSectionHeaderKeepsItsText(_ locale: String, _ expected: String) throws {
        let path = try #require(AppLocalization.bundle.path(forResource: locale, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let format = bundle.localizedString(forKey: "regions.section.alarm %lld", value: nil, table: nil)

        #expect(String(format: format, 3) == expected)
    }
}
