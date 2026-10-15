import CoreLocation
@testable import RegionalCheck
import Testing

struct LocationAuthorizationPolicyTests {
    @Test
    func blockedStatuses() {
        #expect(LocationAuthorizationPolicy.isBlocked(.denied))
        #expect(LocationAuthorizationPolicy.isBlocked(.restricted))
        #expect(LocationAuthorizationPolicy.isBlocked(.authorizedWhenInUse) == false)
        #expect(LocationAuthorizationPolicy.isBlocked(.authorizedAlways) == false)
        #expect(LocationAuthorizationPolicy.isBlocked(.notDetermined) == false)
    }
}

@MainActor
struct LocationAuthorizationRecoveryTests {
    @Test("REQ-REGION-009: a location update error cannot revoke system permission")
    func deniedUpdatePreservesAuthorizedPermission() async {
        let system = AuthorizationLocationStub()
        system.currentStatus = .authorizedWhenInUse
        let location = LocationManager(manager: system)
        await withCheckedContinuation { continuation in
            system.onStop = { continuation.resume() }
            location.receive(failure: CLError(.denied))
        }
        #expect(!location.isAuthorizationBlocked)
        #expect(location.authorizationStatus == .authorizedWhenInUse)
    }

    @Test("REQ-REGION-009: foreground refresh reflects a restored system permission")
    func restoredPermissionClearsTheBlockedState() {
        let system = AuthorizationLocationStub()
        let location = LocationManager(manager: system)
        #expect(location.isAuthorizationBlocked)
        system.currentStatus = .authorizedWhenInUse
        location.refreshAuthorization()
        #expect(!location.isAuthorizationBlocked)
        #expect(location.authorizationStatus == .authorizedWhenInUse)
    }
}

@MainActor
struct LocationPromptTests {
    @Test("REQ-REGION-010 creating the location manager or refreshing its status never raises the system prompt")
    func noPromptWithoutAClient() {
        let system = AuthorizationLocationStub()
        system.currentStatus = .notDetermined
        let location = LocationManager(manager: system)

        // What CoreLocation's authorization callback does right after the delegate is set.
        location.refreshAuthorization()

        #expect(system.authorizationRequests == 0)
    }

    @Test("REQ-REGION-010 the prompt is raised by the first client and not again by the next")
    func firstClientRaisesThePromptOnce() {
        let system = AuthorizationLocationStub()
        system.currentStatus = .notDetermined
        let location = LocationManager(manager: system)

        location.beginUpdating()
        #expect(system.authorizationRequests == 1)

        location.endUpdating()
        location.refreshAuthorization()
        #expect(system.authorizationRequests == 1)
    }
}

@MainActor
struct LocationUpdatesTests {
    @Test("REQ-REGION-005 location updates never pause automatically while driving")
    func configuresAutomotiveUpdatesWithoutPausing() {
        let system = AuthorizationLocationStub()
        let location = LocationManager(manager: system)

        #expect(system.activityType == .automotiveNavigation)
        #expect(system.pausesLocationUpdatesAutomatically == false)
        #expect(system.delegate === location)
    }

    @Test("REQ-REGION-005 an authorized client starts updates and the last client to leave stops them")
    func authorizedClientsStartAndStopUpdates() {
        let system = AuthorizationLocationStub()
        system.currentStatus = .authorizedWhenInUse
        let location = LocationManager(manager: system)

        location.beginUpdating()
        location.beginUpdating()
        #expect(system.startRequests == 2)

        location.endUpdating()
        #expect(system.stopRequests == 0)
        location.endUpdating()
        #expect(system.stopRequests == 1)
    }

    @Test("REQ-REGION-009 a denied client stops updates instead of starting them")
    func deniedClientStopsUpdates() {
        let system = AuthorizationLocationStub()
        system.currentStatus = .denied
        let location = LocationManager(manager: system)

        location.beginUpdating()

        #expect(system.startRequests == 0)
        #expect(system.stopRequests == 1)
    }

    @Test("REQ-REGION-005 a location update records the fix and advances the coordinate stamp")
    func locationUpdateRecordsTheFix() async {
        let location = LocationManager(manager: AuthorizationLocationStub())
        let timestamp = Date(timeIntervalSince1970: 1000)
        let update = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 49.84, longitude: 24.03),
            altitude: 0,
            horizontalAccuracy: 50,
            verticalAccuracy: -1,
            timestamp: timestamp
        )

        location.receive(locations: [update])
        for _ in 0..<200 where location.coordinateStamp == 0 {
            await Task.yield()
        }

        #expect(location.coordinateStamp == 1)
        #expect(location.lastFix == LocationFix(location: update))
        #expect(location.coordinate?.latitude == 49.84)
    }
}

private final class AuthorizationLocationStub: LocationManaging {
    var currentStatus: CLAuthorizationStatus = .denied
    var authorizationStatus: CLAuthorizationStatus {
        currentStatus
    }

    weak var delegate: (any CLLocationManagerDelegate)?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    var activityType: CLActivityType = .other
    var pausesLocationUpdatesAutomatically = true

    private(set) var authorizationRequests = 0
    private(set) var startRequests = 0
    private(set) var stopRequests = 0
    var onStop: (() -> Void)?

    func requestWhenInUseAuthorization() {
        authorizationRequests += 1
    }

    func startUpdatingLocation() {
        startRequests += 1
    }

    func stopUpdatingLocation() {
        stopRequests += 1
        let callback = onStop
        onStop = nil
        callback?()
    }
}
