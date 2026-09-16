import Foundation
import Testing

/// Reads source catalogs because the widget extension and DriveCheckKit bundles
/// are not reachable from the app test host.
struct StatusWordingConsistencyTests {
    private static let statusKeys = ["All Clear", "Alert Active"]

    private static let catalogPaths = [
        "RegionalCheck/Resources/Localizable.xcstrings",
        "RegionalCheckWidgets/Localizable.xcstrings",
        "Packages/DriveCheckKit/Sources/DriveCheckKit/Resources/Localizable.xcstrings"
    ]

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("REQ-SURF-001 status keys share one wording per locale across catalogs")
    func statusWordingMatchesAcrossCatalogs() throws {
        let catalogs = try Self.catalogPaths.map { path in
            try (path, Self.statusValues(in: Self.repositoryRoot.appendingPathComponent(path)))
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

    @Test("REQ-SURF-001 status keys use the approved English wording")
    func statusWordingUsesApprovedEnglish() throws {
        for path in Self.catalogPaths {
            let values = try Self.statusValues(in: Self.repositoryRoot.appendingPathComponent(path))
            #expect(values["All Clear"]?["en"] == "No Alert", "\(path)")
            #expect(values["Alert Active"]?["en"] == "Alert", "\(path)")
        }
    }

    /// Returns `[key: [locale: value]]` for the status keys.
    private static func statusValues(in url: URL) throws -> [String: [String: String]] {
        let data = try Data(contentsOf: url)
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        var result: [String: [String: String]] = [:]
        for key in statusKeys {
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
