import CoreLocation
import Foundation
import RegionalCheckDomain

@MainActor
final class RegionSelectionViewModel: ObservableObject {
    @Published private(set) var selectedRegion: AlertRegion
    @Published private(set) var selectedRegionTitle: String

    private let geocoder = CLGeocoder()
    private let onChange: @MainActor (AlertRegion, String) -> Void

    private var isResolving: Bool = false

    init(onChange: @escaping @MainActor (AlertRegion, String) -> Void) {
        self.onChange = onChange

        if let persisted = SelectedRegionPersistence.shared.load() {
            self.selectedRegion = persisted.region
            self.selectedRegionTitle = persisted.title
        } else {
            self.selectedRegion = .kyivCity
            self.selectedRegionTitle = "Kyiv"
        }
        onChange(selectedRegion, selectedRegionTitle)
    }

    func updateFromLocation(coordinate: CLLocationCoordinate2D) {
        guard !isResolving else { return }
        isResolving = true

        Task {
            defer { isResolving = false }

            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "uk_UA"))
                guard let placemark = placemarks.first else { return }
                guard placemark.isoCountryCode == "UA" else { return }

                let resolved: ResolvedRegion?

                if let city = placemark.locality, city == "Київ" || city == "Kyiv" {
                    resolved = ResolvedRegion(
                        kind: .kyivCity,
                        title: "Kyiv",
                        region: .kyivCity
                    )
                } else if let admin = placemark.administrativeArea, !admin.isEmpty {
                    // With `uk_UA` locale this is typically "Київська область", etc.
                    resolved = ResolvedRegion(
                        kind: .region(name: admin),
                        title: admin,
                        region: AlertRegion(kind: .oblast(name: admin))
                    )
                } else {
                    resolved = nil
                }

                guard let resolved else { return }

                if resolved.region != selectedRegion {
                    selectedRegion = resolved.region
                    selectedRegionTitle = resolved.title
                    SelectedRegionPersistence.shared.save(.init(kind: resolved.kind, title: resolved.title))
                    onChange(resolved.region, resolved.title)
                }
            } catch {
                // Best-effort: keep previous region.
            }
        }
    }

    private struct ResolvedRegion: Sendable {
        let kind: SelectedRegionPersistence.Record.Kind
        let title: String
        let region: AlertRegion
    }
}

