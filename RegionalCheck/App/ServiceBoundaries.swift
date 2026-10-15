import DriveCheckKit
import Foundation
import UIKit

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

@MainActor
protocol WidgetReloading: Sendable {
    func reloadAllTimelines()
}

/// Consumers: `HomeViewModel`, `DetailsViewModel`, and the CarPlay path through
/// `CarPlayLocationSource`.
@MainActor
protocol HomeLocationSource: AnyObject {
    var isAuthorizationBlocked: Bool { get }
}

/// Consumers: `MainTabViewModel` and the CarPlay scene through `CarPlayLocationSource`.
@MainActor
protocol LocationSessionManaging: AnyObject {
    var lastFix: LocationFix? { get }
    func beginUpdating()
    func endUpdating()
    func refreshAuthorization()
}

extension LocationSessionManaging {
    func refreshAuthorization() {}
}

/// Opens this app's page in iOS Settings, so a view model can offer the route without the view
/// reaching for `UIApplication`. Consumers: `HomeViewModel` and `DetailsViewModel`.
@MainActor
protocol SettingsOpening {
    func openSettings()
}

struct SystemSettingsOpener: SettingsOpening {
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Read-only access to the region owner for the list and shared status follower (ADR 0015).
/// Consumers: `RegionListViewModel` and `StatusController.follow(_:)`.
@MainActor
protocol CurrentRegionSource: AnyObject {
    var selectedRegion: AlertRegion { get }
}

extension StatusController: RegionStatusSource {}
extension LocationManager: LocationFixProviding {}
extension LocationManager: HomeLocationSource {}
extension LocationManager: LocationSessionManaging {}
extension RegionSelection: CurrentRegionSource {}
extension SharedStore: EntitlementPersisting {}
