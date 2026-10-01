import CoreLocation
import Foundation
import MapKit

struct GeocodedAddress: Equatable, Sendable {
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
            administrativeAreaName: Self.administrativeAreaName(from: address)
        )
    }

    private static func administrativeAreaName(from address: MKAddressRepresentations) -> String? {
        guard let full = address.cityWithContext(.full) else { return nil }
        var parts =
            full
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let city = address.cityName {
            parts.removeAll { $0 == city }
        }
        if let country = address.regionName {
            parts.removeAll { $0 == country }
        }

        return parts.first
    }
}
