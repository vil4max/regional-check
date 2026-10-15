import Foundation

/// A source String Catalog (`.xcstrings`) read from the repository. The widget extension and
/// DriveCheckKit bundles are not reachable from the app test host, and a wording contract is
/// checked in every locale at once, so these tests read the catalogs the targets are built from.
struct StringCatalog {
    static let mainPath = "RegionalCheck/Resources/Localizable.xcstrings"
    static let widgetsPath = "RegionalCheckWidgets/Localizable.xcstrings"
    static let kitPath = "Packages/DriveCheckKit/Sources/DriveCheckKit/Resources/Localizable.xcstrings"

    let path: String
    /// `[key: [locale: value]]` for every key; a locale without a string unit is left out. A plural
    /// string has no top-level unit: it counts with its "other" form, and only when every form is
    /// translated.
    let values: [String: [String: String]]

    init(path: String) throws {
        let data = try Data(contentsOf: Self.repositoryRoot.appendingPathComponent(path))
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        self.path = path
        values = catalog.strings.mapValues { entry in
            (entry.localizations ?? [:]).compactMapValues(\.translatedValue)
        }
    }

    /// Support/ → RegionalCheckTests/ → the repository root.
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private struct Catalog: Decodable {
        let strings: [String: Entry]
    }

    private struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    private struct Localization: Decodable {
        let stringUnit: StringUnit?
        let variations: Variations?

        var translatedValue: String? {
            if let value = stringUnit?.value {
                return value
            }
            guard let forms = variations?.plural, !forms.isEmpty,
                forms.values.allSatisfy({ $0.stringUnit?.value.isEmpty == false })
            else { return nil }
            return forms["other"]?.stringUnit?.value
        }
    }

    private struct Variations: Decodable {
        let plural: [String: Localization]?
    }

    private struct StringUnit: Decodable {
        let value: String
    }
}
