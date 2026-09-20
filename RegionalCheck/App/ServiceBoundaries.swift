import DriveCheckKit
import Foundation

// Placement rule (ADR 0008): a protocol with more than one consumer lives here, at the
// application boundary, together with its live conformances, so no feature file owns a
// contract other features depend on. A protocol with a single consumer stays next to that
// consumer.

@MainActor
protocol RegionStatusSource: AnyObject {
    var lastSnapshot: AlertsSnapshot? { get }

    /// Suspends until an alert-status refresh next settles (success or
    /// failure), or returns immediately when none is in flight and a
    /// snapshot already exists. `MapViewModel` awaits this before its first
    /// automatic load so it never races the status fetch that starts at the
    /// same appear. Default: returns immediately (no status fetch to wait on).
    func awaitStatusSettled() async
}

extension RegionStatusSource {
    func awaitStatusSettled() async {}
}

@MainActor
protocol LocationFixProviding: AnyObject {
    var lastFix: LocationFix? { get }
}

protocol SecondaryRegionStore: Sendable {
    func saveSecondaryRegion(_ region: AlertRegion?)
    func loadSecondaryRegion() -> AlertRegion?
}

@MainActor
protocol WidgetReloading: Sendable {
    func reloadAllTimelines()
}

extension StatusController: RegionStatusSource {}
extension LocationManager: LocationFixProviding {}
extension SharedStore: SecondaryRegionStore {}
extension SharedStore: EntitlementPersisting {}
