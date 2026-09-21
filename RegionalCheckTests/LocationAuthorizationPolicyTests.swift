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
            location.locationManager(system, didFailWithError: CLError(.denied))
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

private final class AuthorizationLocationStub: CLLocationManager {
    private(set) var authorizationRequests = 0

    override func requestWhenInUseAuthorization() {
        authorizationRequests += 1
    }

    var currentStatus: CLAuthorizationStatus = .denied
    override var authorizationStatus: CLAuthorizationStatus {
        currentStatus
    }

    var onStop: (() -> Void)?

    override func stopUpdatingLocation() {
        let callback = onStop
        onStop = nil
        callback?()
    }
}
