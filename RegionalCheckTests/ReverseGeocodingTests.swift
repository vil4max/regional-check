import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// Address shapes follow MapKit's `cityWithContext(.full)` line: "city, area, country", in the
/// language of the request's preferred locale (the app asks for `uk_UA`).
struct AdministrativeAreaParserTests {
    private static func area(_ full: String?, city: String?, country: String?) -> String? {
        MapKitReverseGeocoder.administrativeAreaName(cityWithContext: full, cityName: city, countryName: country)
    }

    @Test(
        "REQ-REGION-004 the oblast is the part between the city and the country, in uk, ru and en",
        arguments: [
            ("Чернігів, Чернігівська область, Україна", "Чернігів", "Україна", "Чернігівська область"),
            ("Харьков, Харьковская область, Украина", "Харьков", "Украина", "Харьковская область"),
            ("Lviv, Lviv Oblast, Ukraine", "Lviv", "Ukraine", "Lviv Oblast"),
        ])
    func oblastBetweenCityAndCountry(full: String, city: String, country: String, expected: String) {
        #expect(Self.area(full, city: city, country: country) == expected)
    }

    @Test("REQ-REGION-004 a city-only line has no oblast")
    func cityOnly() {
        #expect(Self.area("Київ, Україна", city: "Київ", country: "Україна") == nil)
        #expect(Self.area("Kyiv", city: "Kyiv", country: nil) == nil)
    }

    @Test("REQ-REGION-004 an oblast-only line, outside any city, yields the oblast")
    func oblastOnly() {
        #expect(Self.area("Житомирська область, Україна", city: nil, country: "Україна") == "Житомирська область")
        #expect(Self.area("Одеська область", city: nil, country: nil) == "Одеська область")
    }

    @Test("REQ-REGION-004 no context line means no oblast")
    func missingLine() {
        #expect(Self.area(nil, city: "Київ", country: "Україна") == nil)
        #expect(Self.area(" , ", city: nil, country: nil) == nil)
    }

    @Test("REQ-REGION-004 Kyiv city and a town in Kyiv oblast resolve to different regions")
    func kyivCityVersusKyivOblast() {
        let cityArea = Self.area("Київ, Україна", city: "Київ", country: "Україна")
        #expect(AlertRegionResolver.resolve(cityName: "Київ", administrativeArea: cityArea) == .kyivCity)

        let townArea = Self.area("Бровари, Київська область, Україна", city: "Бровари", country: "Україна")
        #expect(townArea == "Київська область")
        #expect(AlertRegionResolver.resolve(cityName: "Бровари", administrativeArea: townArea) == .kyivOblast)
    }
}

struct TimeoutReverseGeocoderTests {
    private struct ImmediateSleeping: BoundedAwait.Sleeping {
        func sleep(for _: Duration) async throws {}
    }

    private struct UntilCancelledSleeping: BoundedAwait.Sleeping {
        func sleep(for _: Duration) async throws {
            try await Task.sleep(for: .seconds(3600))
        }
    }

    private struct HungGeocoder: ReverseGeocoding {
        func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
            try await Task.sleep(for: .seconds(3600))
            return nil
        }
    }

    private struct AnsweringGeocoder: ReverseGeocoding {
        func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
            GeocodedAddress(countryCode: "UA", cityName: "Харків", administrativeAreaName: "Харківська область")
        }
    }

    private static let kharkiv = CLLocationCoordinate2D(latitude: 49.99, longitude: 36.23)

    @Test("REQ-REGION-005 a lookup that never returns throws once the timeout passes")
    func hungLookupThrows() async {
        let geocoder = TimeoutReverseGeocoder(base: HungGeocoder(), sleeping: ImmediateSleeping())
        do {
            _ = try await geocoder.reverseGeocode(coordinate: Self.kharkiv)
            Issue.record("Expected deadlineExceeded")
        } catch {
            #expect(error as? ExplanationRunError == .deadlineExceeded)
        }
    }

    @Test("REQ-REGION-005 a lookup that answers in time passes its address through")
    func answeredLookupPassesThrough() async throws {
        let geocoder = TimeoutReverseGeocoder(base: AnsweringGeocoder(), sleeping: UntilCancelledSleeping())
        let address = try await geocoder.reverseGeocode(coordinate: Self.kharkiv)
        #expect(address?.administrativeAreaName == "Харківська область")
    }

    @Test("REQ-REGION-005 a timed-out lookup defers the fix for a retry instead of stopping tracking")
    @MainActor
    func timedOutLookupDefersTheFix() async {
        let now = Date(timeIntervalSince1970: 1000)
        let tracker = RegionTracker(
            geocoder: TimeoutReverseGeocoder(base: HungGeocoder(), sleeping: ImmediateSleeping()),
            now: { now }
        )
        let fix = LocationFix(coordinate: Self.kharkiv, horizontalAccuracy: 50, timestamp: now)
        #expect(
            await tracker.evaluate(fix: fix, current: .kyivCity)
                == .deferred(retryAfter: RegionTracker.geocodeMinInterval))
    }
}

@MainActor
struct MissingCountryCodeTests {
    private struct NoCountryGeocoder: ReverseGeocoding {
        func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
            GeocodedAddress(countryCode: nil, cityName: "Харків", administrativeAreaName: "Харківська область")
        }
    }

    @Test("REQ-REGION-008 an address without a country code counts as outside Ukraine")
    func missingCountryCodeIsOutsideUkraine() async {
        let now = Date(timeIntervalSince1970: 1000)
        let tracker = RegionTracker(geocoder: NoCountryGeocoder(), now: { now })
        let fix = LocationFix(
            coordinate: CLLocationCoordinate2D(latitude: 49.99, longitude: 36.23),
            horizontalAccuracy: 50,
            timestamp: now
        )

        #expect(await tracker.evaluate(fix: fix, current: .kyivCity) == .outsideUkraine)
        #expect(tracker.isOutsideUkraine)
    }
}
