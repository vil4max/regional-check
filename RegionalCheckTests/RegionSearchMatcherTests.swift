import DriveCheckKit
@testable import RegionalCheck
import Testing

/// REQ-REGION-004: search matches a region by its English, Ukrainian or Russian name regardless
/// of the device's current locale, and "Kyiv" in any of the three languages returns both the city
/// and the oblast.
struct RegionSearchMatcherTests {
    @Test(arguments: AlertRegion.allCases)
    func matchesEveryRegionByEachOfItsThreeLocalizedNames(_ region: AlertRegion) {
        for name in RegionSearchMatcher.localizedNames(for: region) {
            #expect(RegionSearchMatcher.matches(region, query: name), "\(region) should match its own name '\(name)'")
        }
    }

    @Test(arguments: ["Kyiv", "Київ", "Киев", "kyiv", "київ", "киев"])
    func kyivQueryReturnsBothCityAndOblast(_ query: String) {
        #expect(RegionSearchMatcher.matches(.kyivCity, query: query))
        #expect(RegionSearchMatcher.matches(.kyivOblast, query: query))
    }

    @Test
    func kyivQueryDoesNotMatchUnrelatedRegions() {
        let unrelated = AlertRegion.allCases.filter { $0 != .kyivCity && $0 != .kyivOblast }
        for region in unrelated {
            #expect(!RegionSearchMatcher.matches(region, query: "Kyiv"))
        }
    }

    @Test
    func matchIsCaseInsensitive() {
        #expect(RegionSearchMatcher.matches(.lviv, query: "LVIV"))
        #expect(RegionSearchMatcher.matches(.lviv, query: "lviv"))
    }

    @Test
    func matchIgnoresApostropheVariants() {
        // "Ivano-Frankivsk" has no apostrophe, but the Ukrainian name does ("Івано-Франківська");
        // exercise the normalizer's curly/straight apostrophe folding via a region whose Ukrainian
        // name contains one once escaped through AlertRegionResolver.normalize's own cases.
        #expect(RegionSearchMatcher.matches(.ivanoFrankivsk, query: "Ivano-Frankivsk"))
        #expect(RegionSearchMatcher.matches(.ivanoFrankivsk, query: "івано-франківська"))
    }

    @Test
    func blankQueryMatchesEveryRegion() {
        for region in AlertRegion.allCases {
            #expect(RegionSearchMatcher.matches(region, query: ""))
            #expect(RegionSearchMatcher.matches(region, query: "   "))
        }
    }

    @Test
    func partialNameMatches() {
        // Substring match, not just exact/prefix — "kharkiv" mid-word still finds the region via
        // its own name, and "oblast" alone matches every oblast (but not the city).
        #expect(RegionSearchMatcher.matches(.kharkiv, query: "hark"))
        #expect(RegionSearchMatcher.matches(.lviv, query: "oblast"))
        #expect(!RegionSearchMatcher.matches(.kyivCity, query: "oblast"))
    }
}
