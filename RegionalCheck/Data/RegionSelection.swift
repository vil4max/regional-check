import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class RegionSelection {
    private(set) var selectedRegion: AlertRegion

    private var isResolving = false

    init() {
        selectedRegion = RegionStore.shared.load() ?? .kyivCity
    }

    func updateFromLocation(coordinate: CLLocationCoordinate2D) {
        guard !isResolving else { return }
        isResolving = true

        Task {
            defer { isResolving = false }

            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard let request = MKReverseGeocodingRequest(location: location) else { return }
            request.preferredLocale = Locale(identifier: "uk_UA")

            do {
                let mapItems = try await request.mapItems
                guard let address = mapItems.first?.addressRepresentations else { return }
                guard address.region?.identifier == "UA" else { return }

                let resolved: AlertRegion?

                if let city = address.cityName, city == "Київ" || city == "Kyiv" {
                    resolved = .kyivCity
                } else if let admin = Self.administrativeAreaName(from: address), !admin.isEmpty {
                    resolved = AlertRegion(kind: .oblast(name: admin))
                } else {
                    resolved = nil
                }

                guard let resolved else { return }
                apply(resolved)
            } catch {
            }
        }
    }

    private func apply(_ region: AlertRegion) {
        guard region != selectedRegion else { return }
        selectedRegion = region
        RegionStore.shared.save(region)
    }

    private static func administrativeAreaName(from address: MKAddressRepresentations) -> String? {
        guard let full = address.cityWithContext(.full) else { return nil }
        var parts = full
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
