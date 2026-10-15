import CoreLocation
import Observation
import os

/// The `CLLocationManager` members `LocationManager` uses, so tests can drive it without
/// CoreLocation.
protocol LocationManaging: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var activityType: CLActivityType { get set }
    var pausesLocationUpdatesAutomatically: Bool { get set }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: LocationManaging {}

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Location")

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var lastFix: LocationFix?
    private(set) var coordinateStamp: Int = 0

    var isAuthorizationBlocked: Bool {
        LocationAuthorizationPolicy.isBlocked(authorizationStatus)
    }

    private let manager: any LocationManaging
    private var clientCount = 0

    init(manager: any LocationManaging = CLLocationManager()) {
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 2000
        manager.activityType = .automotiveNavigation
        // Apple's pausesLocationUpdatesAutomatically documentation: the default is true, and with
        // in-use authorization a pause "ends access to location changes until the app launches
        // again". A stop at a fuel station would end region tracking for the drive, so pausing is
        // off; the kilometre accuracy and 2 km filter above already keep the power cost low.
        manager.pausesLocationUpdatesAutomatically = false
        manager.delegate = self
    }

    func beginUpdating() {
        clientCount += 1
        refreshAuthorization()
    }

    func refreshAuthorization() {
        authorizationStatus = manager.authorizationStatus
        requestAuthorizationIfNeeded()
    }

    func endUpdating() {
        clientCount = max(0, clientCount - 1)
        if clientCount == 0 {
            manager.stopUpdatingLocation()
        }
    }

    /// Every branch that talks to the system is gated on having a client (REQ-REGION-010). Setting
    /// the delegate in `init` makes CoreLocation call `locationManagerDidChangeAuthorization`
    /// straight away, so an ungated `.notDetermined` branch raised the permission prompt from the
    /// container's construction — before onboarding had said what location is for — whatever the
    /// session's own gate did. `beginUpdating()` increments the count before it calls this.
    private func requestAuthorizationIfNeeded() {
        guard clientCount > 0 else { return }
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .restricted, .denied:
            manager.stopUpdatingLocation()
        @unknown default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        Task { @MainActor in
            refreshAuthorization()
        }
    }

    nonisolated func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        receive(locations: locations)
    }

    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        receive(failure: error)
    }

    /// The delegate callbacks' bodies, without the `CLLocationManager` argument they never read.
    nonisolated func receive(locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let fix = LocationFix(location: last)
        Task { @MainActor in
            coordinate = fix.coordinate
            lastFix = fix
            coordinateStamp &+= 1
        }
    }

    /// Reads the owned `manager` on the main actor rather than the callback's argument: the two are
    /// the same object (this type is its only delegate), and capturing the nonisolated argument
    /// would send a non-Sendable `CLLocationManager` across the actor boundary.
    nonisolated func receive(failure error: Error) {
        let denied = (error as? CLError)?.code == .denied
        Task { @MainActor in
            Self.log.error("Location update failed: \(String(describing: error), privacy: .public)")
            if denied {
                authorizationStatus = manager.authorizationStatus
                manager.stopUpdatingLocation()
            }
        }
    }
}
