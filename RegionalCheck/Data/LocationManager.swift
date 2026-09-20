import CoreLocation
import Observation
import os

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

    private let manager: CLLocationManager
    private var clientCount = 0

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 2000
        manager.activityType = .automotiveNavigation
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

    private func requestAuthorizationIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            if clientCount > 0 {
                manager.startUpdatingLocation()
            }
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
    nonisolated func locationManager(_: CLLocationManager, didFailWithError error: Error) {
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
