import CoreLocation
import Foundation
import MapKit

struct GeocodedAddress: Equatable, Sendable {
    /// A missing code counts as outside Ukraine on purpose (REQ-REGION-008: `countryCode != UA`).
    var countryCode: String?
    var cityName: String?
    var administrativeAreaName: String?
}

protocol ReverseGeocoding: Sendable {
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedAddress?
}

struct MapKitReverseGeocoder: ReverseGeocoding {
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        request.preferredLocale = Locale(identifier: "uk_UA")
        let mapItems = try await request.mapItems
        guard let address = mapItems.first?.addressRepresentations else { return nil }
        return GeocodedAddress(
            countryCode: address.region?.identifier,
            cityName: address.cityName,
            administrativeAreaName: Self.administrativeAreaName(
                cityWithContext: address.cityWithContext(.full),
                cityName: address.cityName,
                countryName: address.regionName
            )
        )
    }

    /// MapKit gives no administrative-area field, so the oblast is the first part of the
    /// comma-separated "city, area, country" line that is neither the city nor the country.
    static func administrativeAreaName(
        cityWithContext full: String?,
        cityName: String?,
        countryName: String?
    ) -> String? {
        guard let full else { return nil }
        var parts =
            full
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let cityName {
            parts.removeAll { $0 == cityName }
        }
        if let countryName {
            parts.removeAll { $0 == countryName }
        }

        return parts.first
    }
}

/// Bounds each lookup so one hung MapKit request cannot stop region tracking: `RegionSelection`
/// evaluates fixes one at a time, so a lookup that never returns would hold every later fix. The
/// deadline error is an ordinary geocode failure, which `RegionTracker` defers and retries.
struct TimeoutReverseGeocoder: ReverseGeocoding {
    static let defaultTimeout: Duration = .seconds(15)

    let base: any ReverseGeocoding
    var timeout: Duration = defaultTimeout
    var sleeping: any BoundedAwait.Sleeping = BoundedAwait.ContinuousSleeping()

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
        let base = base
        return try await BoundedAwait.value(timeout: timeout, sleeping: sleeping) {
            try await base.reverseGeocode(coordinate: coordinate)
        }
    }
}
