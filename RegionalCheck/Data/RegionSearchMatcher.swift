import DriveCheckKit
import Foundation

/// Matches a region against free-text search input across its English, Ukrainian and Russian
/// names, regardless of the device's current locale (REQ-REGION-004). Reuses
/// `AlertRegionResolver.normalize` so casing, apostrophes and whitespace are handled the same way
/// as location resolution.
///
/// A query matches by substring, not exact equality: "Kyiv" is a substring of the English "Kyiv
/// Oblast", and "Київ"/"Киев" are substrings of the Ukrainian/Russian oblast names the same way —
/// so "Kyiv"/"Київ"/"Киев" return both `.kyivCity` and `.kyivOblast` without special-casing (Q12).
enum RegionSearchMatcher {
    private static let searchLocales = [
        Locale(identifier: "en"),
        Locale(identifier: "uk"),
        Locale(identifier: "ru")
    ]

    /// `true` for a blank query (nothing to filter on) or when any localized name contains it.
    static func matches(_ region: AlertRegion, query: String) -> Bool {
        guard let normalizedQuery = AlertRegionResolver.normalize(query), !normalizedQuery.isEmpty else {
            return true
        }
        return localizedNames(for: region).contains { name in
            guard let normalizedName = AlertRegionResolver.normalize(name) else { return false }
            return normalizedName.contains(normalizedQuery)
        }
    }

    static func localizedNames(for region: AlertRegion) -> [String] {
        searchLocales.map { region.title(locale: $0) }
    }
}
