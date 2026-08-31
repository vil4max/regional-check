import CoreLocation
import DriveCheckKit
import Foundation
import Observation

@MainActor
@Observable
final class RegionSelection {
    private(set) var selectedRegion: AlertRegion
    private(set) var followsLocation: Bool
    private(set) var regionChangeNotice: String?
    private(set) var previousRegionForUndo: AlertRegion?

    private let store: RegionStore
    private let tracker: RegionTracker
    private var locationUpdateTask: Task<Void, Never>?

    init(
        store: RegionStore = .shared,
        geocoder: any ReverseGeocoding = MapKitReverseGeocoder(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        tracker = RegionTracker(geocoder: geocoder, now: now)
        selectedRegion = store.load() ?? .kyivCity
        followsLocation = store.loadFollowsLocation()
    }

    func dismissRegionChangeNotice() {
        regionChangeNotice = nil
        previousRegionForUndo = nil
    }

    func undoRegionChange() {
        guard let previous = previousRegionForUndo else { return }
        apply(previous, announce: false)
        dismissRegionChangeNotice()
    }

    func pin(_ region: AlertRegion) {
        followsLocation = false
        store.saveFollowsLocation(false)
        apply(region, announce: false)
        dismissRegionChangeNotice()
    }

    func setFollowsLocation(_ enabled: Bool, immediateFix: LocationFix? = nil) {
        followsLocation = enabled
        store.saveFollowsLocation(enabled)
        guard enabled, let fix = immediateFix else { return }
        Task {
            let outcome = await tracker.evaluateImmediate(fix: fix, current: selectedRegion)
            switch outcome {
            case let .committed(region):
                apply(region, announce: false)
            case .outsideUkraine:
                applyOutsideUkraine()
            case .ignored, .unchanged, .candidate:
                break
            }
        }
    }

    func updateFromLocation(fix: LocationFix) {
        guard followsLocation else { return }

        locationUpdateTask?.cancel()
        locationUpdateTask = Task {
            let outcome = await tracker.evaluate(fix: fix, current: selectedRegion)
            guard !Task.isCancelled else { return }
            switch outcome {
            case .ignored, .unchanged, .candidate:
                break
            case let .committed(region):
                let previous = selectedRegion
                apply(region, announce: true, previous: previous)
            case .outsideUkraine:
                applyOutsideUkraine()
            }
        }
    }

    func updateFromLocation(coordinate: CLLocationCoordinate2D) {
        let fix = LocationFix(
            coordinate: coordinate,
            horizontalAccuracy: 100,
            timestamp: Date()
        )
        updateFromLocation(fix: fix)
    }

    private func applyOutsideUkraine() {
        let previous = selectedRegion
        apply(.kyivCity, announce: previous != .kyivCity, previous: previous)
    }

    private func apply(_ region: AlertRegion, announce: Bool, previous: AlertRegion? = nil) {
        guard region != selectedRegion else { return }
        if announce {
            previousRegionForUndo = previous ?? selectedRegion
            regionChangeNotice = String(
                format: String(localized: "regions.changed_notice"),
                region.title
            )
        }
        selectedRegion = region
        store.save(region)
    }
}
