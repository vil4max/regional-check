import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

struct AlertRegionResolverTests {
    @Test
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
            ("  харківська   область  ", .kharkiv)
        ]

        for (input, expected) in cases {
            let resolved = AlertRegionResolver.resolve(cityName: nil, administrativeArea: input)
            #expect(resolved == expected, "input=\(input) got=\(String(describing: resolved))")
        }
    }

    @Test
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

    @Test
    func resolve_returnsNilForUnknown() {
        #expect(AlertRegionResolver.resolve(cityName: nil, administrativeArea: "Somewhere") == nil)
        #expect(AlertRegionResolver.resolve(cityName: "Unknown", administrativeArea: nil) == nil)
    }
}
