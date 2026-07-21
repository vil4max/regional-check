import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var coordinateStamp: Int = 0

    private let manager: CLLocationManager
    private var clientCount = 0

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func beginUpdating() {
        clientCount += 1
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
            break
        @unknown default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            requestAuthorizationIfNeeded()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last?.coordinate else { return }
        Task { @MainActor in
            coordinate = last
            coordinateStamp &+= 1
        }
    }
}
