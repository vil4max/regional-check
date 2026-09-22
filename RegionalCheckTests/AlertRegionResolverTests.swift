import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct AlertRegionResolverTests {
    @Test("REQ-REGION-004 oblast names resolve in their Ukrainian and English forms")
    func resolve_knownVariants() {
        let cases: [(String, AlertRegion)] = [
            ("м. Київ", .kyivCity),
            ("Київ", .kyivCity),
            ("Kyiv", .kyivCity),
            ("Kiev", .kyivCity),
            ("Чернігівська область", .chernihiv),
            ("Чернігівська обл.", .chernihiv),
            ("Чернігівська обл", .chernihiv),
            ("Chernihiv Oblast", .chernihiv),
            ("Львівська область", .lviv),
            ("Lviv Oblast", .lviv),
            ("Івано-Франківська область", .ivanoFrankivsk),
            ("  харківська   область  ", .kharkiv),
        ]

        for (input, expected) in cases {
            let resolved = AlertRegionResolver.resolve(cityName: nil, administrativeArea: input)
            #expect(resolved == expected, "input=\(input) got=\(String(describing: resolved))")
        }
    }

    @Test("REQ-REGION-004 Kyiv city wins over Kyiv Oblast when the city matches")
    func resolve_prefersKyivCityOverOblastWhenCityMatches() {
        #expect(
            AlertRegionResolver.resolve(cityName: "Київ", administrativeArea: "Київська область")
                == .kyivCity
        )
        #expect(
            AlertRegionResolver.resolve(cityName: "Kiev", administrativeArea: "Kyiv Oblast")
                == .kyivCity
        )
    }

    @Test("REQ-REGION-004 an unknown place resolves to nothing, so the current region is kept")
    func resolve_returnsNilForUnknown() {
        #expect(AlertRegionResolver.resolve(cityName: nil, administrativeArea: "Somewhere") == nil)
        #expect(AlertRegionResolver.resolve(cityName: "Unknown", administrativeArea: nil) == nil)
    }
}
