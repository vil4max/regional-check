import CoreLocation
import Foundation

final class UserLocationManager: NSObject, ObservableObject {
    @MainActor @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @MainActor @Published private(set) var coordinate: CLLocationCoordinate2D?
    @MainActor @Published private(set) var coordinateStamp: Int = 0
    @MainActor var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

    private let manager: CLLocationManager

    @MainActor
    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    @MainActor
    func requestAuthorizationIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .restricted, .denied:
            break
        @unknown default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }
}

extension UserLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            requestAuthorizationIfNeeded()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last?.coordinate else { return }
        Task { @MainActor in
            coordinate = last
            coordinateStamp &+= 1
            onLocationUpdate?(last)
        }
    }
}

