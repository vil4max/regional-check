import CoreLocation
import DriveCheckKit
import Foundation
import Observation

@MainActor
@Observable
final class RegionSelection {
    private(set) var selectedRegion: AlertRegion
    /// Always `true` since 3.0: the region is resolved from location only (ADR 0015,
    /// REQ-REGION-003 retired), and the stored flag is vestigial (REQ-REGION-002). It survives as
    /// a constant only because the CarPlay call sites still read it; they were out of scope for
    /// the slice that removed the manual pin, and the property goes when they stop.
    let followsLocation = true
    private(set) var isOutsideUkraine = false
    private(set) var regionChangeNotice: String?
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
    }

    func dismissRegionChangeNotice() {
        regionChangeNotice = nil
    }

    /// Called when the outside-Ukraine sheet is dismissed, so it does not show again until the
    /// next inside→outside transition (REQ-REGION-008).
    func acknowledgeOutsideUkraineSheet() {
        shouldShowOutsideUkraineSheet = false
    }

    func updateFromLocation(fix: LocationFix) {
        locationUpdateTask?.cancel()
        locationUpdateTask = Task {
            let outcome = await tracker.evaluate(fix: fix, current: selectedRegion)
            guard !Task.isCancelled else { return }
            let wasOutsideUkraine = isOutsideUkraine
            isOutsideUkraine = tracker.isOutsideUkraine
            switch outcome {
            case .ignored, .unchanged, .candidate:
                break
            case let .committed(region):
                commit(region)
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

    /// REQ-REGION-007: every change comes from the tracker, so every change is announced. The
    /// notice has no Undo — restoring the previous region would be a manual pin under another name.
    private func commit(_ region: AlertRegion) {
        guard region != selectedRegion else { return }
        regionChangeNotice = String(
            format: String(localized: "regions.changed_notice"),
            region.title
        )
        selectedRegion = region
        store.save(region)
    }
}
