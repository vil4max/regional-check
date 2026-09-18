import CoreLocation
import DriveCheckKit
import Foundation
import Observation

@MainActor
@Observable
final class RegionSelection {
    private(set) var selectedRegion: AlertRegion
    private(set) var followsLocation: Bool
    private(set) var isOutsideUkraine = false
    private(set) var regionChangeNotice: String?
    private(set) var previousRegionForUndo: AlertRegion?
    /// REQ-REGION-008: set on the inside→outside transition (which also covers "already outside
    /// at launch", since `isOutsideUkraine` starts `false`); cleared by
    /// `acknowledgeOutsideUkraineSheet()` so it does not repeat while the location stays outside,
    /// and can be set again after a later inside→outside transition.
    private(set) var shouldShowOutsideUkraineSheet = false

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

    /// Called when the outside-Ukraine sheet is dismissed, so it does not show again until the
    /// next inside→outside transition (REQ-REGION-008).
    func acknowledgeOutsideUkraineSheet() {
        shouldShowOutsideUkraineSheet = false
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
            guard followsLocation else { return }
            let wasOutsideUkraine = isOutsideUkraine
            isOutsideUkraine = tracker.isOutsideUkraine
            switch outcome {
            case let .committed(region):
                apply(region, announce: false)
            case .outsideUkraine:
                noteOutsideUkraineTransition(wasOutside: wasOutsideUkraine)
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
            guard followsLocation else { return }
            let wasOutsideUkraine = isOutsideUkraine
            isOutsideUkraine = tracker.isOutsideUkraine
            switch outcome {
            case .ignored, .unchanged, .candidate:
                break
            case let .committed(region):
                let previous = selectedRegion
                apply(region, announce: true, previous: previous)
            case .outsideUkraine:
                noteOutsideUkraineTransition(wasOutside: wasOutsideUkraine)
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

    /// REQ-REGION-008: the sheet shows once per inside→outside transition (`wasOutside == false`
    /// covers "already outside at launch" too, since `isOutsideUkraine` starts `false`), never
    /// while the location stays outside. `selectedRegion` is untouched here — the last region
    /// stays selected, Kyiv city only when `init` never found a stored one.
    private func noteOutsideUkraineTransition(wasOutside: Bool) {
        guard isOutsideUkraine, !wasOutside else { return }
        shouldShowOutsideUkraineSheet = true
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
