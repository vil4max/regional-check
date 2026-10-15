import CoreLocation
import DriveCheckKit
import Foundation
import Observation

@MainActor
@Observable
final class RegionSelection {
    private(set) var selectedRegion: AlertRegion
    private(set) var isOutsideUkraine = false
    private(set) var regionChangeNotice: String?
    /// REQ-REGION-008: set on the inside→outside transition (which also covers "already outside
    /// at launch", since `isOutsideUkraine` starts `false`); cleared by
    /// `acknowledgeOutsideUkraineSheet()` so it does not repeat while the location stays outside,
    /// and can be set again after a later inside→outside transition.
    private(set) var shouldShowOutsideUkraineSheet = false

    private let store: RegionStore
    private let tracker: RegionTracker
    private let sleep: @Sendable (Duration) async throws -> Void
    /// Fixes are evaluated one at a time and a finished lookup is never discarded: the phone UI
    /// and CarPlay both forward the same fix, and cancelling the first lookup for the second used
    /// to lose the answer while the throttle blocked the second.
    private var evaluation: Task<Void, Never>?
    private var pendingFix: QueuedFix?
    private var lastSubmittedFix: LocationFix?
    private var retry: Task<Void, Never>?

    private struct QueuedFix {
        let fix: LocationFix
        /// A retried fix may be older than the tracker's age limit; it is still the latest evidence.
        let isRetry: Bool
    }

    init(
        store: RegionStore,
        geocoder: any ReverseGeocoding = TimeoutReverseGeocoder(base: MapKitReverseGeocoder()),
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.store = store
        tracker = RegionTracker(geocoder: geocoder, now: now)
        self.sleep = sleep
        selectedRegion = store.load() ?? .kyivCity
    }

    /// Returns once every queued fix and scheduled retry has been evaluated.
    func settled() async {
        while true {
            if let evaluation {
                await evaluation.value
            } else if let retry {
                await retry.value
                if self.retry == retry {
                    self.retry = nil
                }
            } else {
                return
            }
        }
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
        guard fix != lastSubmittedFix else { return }
        lastSubmittedFix = fix
        pendingFix = QueuedFix(fix: fix, isRetry: false)
        evaluatePendingFix()
    }

    private func evaluatePendingFix() {
        guard evaluation == nil, let queued = pendingFix else { return }
        pendingFix = nil
        evaluation = Task {
            let outcome = await tracker.evaluate(fix: queued.fix, current: selectedRegion, isRetry: queued.isRetry)
            apply(outcome)
            evaluation = nil
            settleRetry(after: outcome, of: queued.fix)
            evaluatePendingFix()
        }
    }

    /// A deferred fix is evaluated again when its wait ends, so a stationary device that delivers
    /// no further fixes still reaches its region. Only a newer fix the tracker acted on supersedes
    /// the retry: an ignored one (too inaccurate, or needing no lookup) must not cancel it, or a
    /// parked car that delivers nothing better would never resolve.
    private func settleRetry(after outcome: RegionTrackerOutcome, of fix: LocationFix) {
        switch outcome {
        case let .deferred(seconds):
            scheduleRetry(of: fix, after: seconds)
        case .ignored:
            break
        case .unchanged, .candidate, .committed, .outsideUkraine:
            retry?.cancel()
            retry = nil
        }
    }

    private func scheduleRetry(of fix: LocationFix, after seconds: TimeInterval) {
        retry?.cancel()
        retry = Task { [sleep] in
            try? await sleep(.seconds(seconds))
            guard !Task.isCancelled else { return }
            retry = nil
            pendingFix = pendingFix ?? QueuedFix(fix: fix, isRetry: true)
            evaluatePendingFix()
        }
    }

    private func apply(_ outcome: RegionTrackerOutcome) {
        let wasOutsideUkraine = isOutsideUkraine
        isOutsideUkraine = tracker.isOutsideUkraine
        switch outcome {
        case .ignored, .unchanged, .candidate, .deferred:
            break
        case let .committed(region):
            commit(region)
        case .outsideUkraine:
            noteOutsideUkraineTransition(wasOutside: wasOutsideUkraine)
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
        store.save(region)
        selectedRegion = region
    }
}
