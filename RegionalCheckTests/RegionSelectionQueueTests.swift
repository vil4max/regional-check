import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RegionSelectionQueueTests {
    private static let kharkiv = GeocodedAddress(
        countryCode: "UA",
        cityName: "Харків",
        administrativeAreaName: "Харківська область"
    )

    @Test("REQ-REGION-006 a fix forwarded twice while its lookup runs resolves once and is not lost")
    func overlappingForwardsOfOneFixResolveOnce() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let geocoder = GatedGeocoder(address: Self.kharkiv)
            let start = Date(timeIntervalSince1970: 10_000)
            let selection = RegionSelection(
                store: RegionStore(sharedStore: SharedStore(userDefaults: defaults, legacyDefaults: defaults)),
                geocoder: geocoder,
                now: { start },
                sleep: { _ in }
            )
            let fix = Self.fix(at: start)

            selection.updateFromLocation(fix: fix)
            await geocoder.waitForCall()
            selection.updateFromLocation(fix: fix)
            selection.updateFromLocation(fix: Self.fix(at: start.addingTimeInterval(1)))
            await geocoder.release()
            await selection.settled()

            #expect(selection.selectedRegion == .kharkiv)
            #expect(await geocoder.callCount == 1)
        }
    }

    @Test("REQ-REGION-005 a fix whose lookup failed is retried without a newer fix")
    func failedLookupIsRetriedForAStationaryDevice() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let geocoder = FailingOnceGeocoder(address: Self.kharkiv)
            let clock = Mutex(Date(timeIntervalSince1970: 10_000))
            let selection = RegionSelection(
                store: RegionStore(sharedStore: SharedStore(userDefaults: defaults, legacyDefaults: defaults)),
                geocoder: geocoder,
                now: { clock.withLock { $0 } },
                sleep: { duration in
                    clock.withLock { $0 = $0.addingTimeInterval(TimeInterval(duration.components.seconds)) }
                }
            )

            selection.updateFromLocation(fix: Self.fix(at: clock.withLock { $0 }))
            await selection.settled()

            #expect(selection.selectedRegion == .kharkiv)
            #expect(geocoder.callCount == 2)
        }
    }

    private static func fix(at timestamp: Date) -> LocationFix {
        LocationFix(
            coordinate: CLLocationCoordinate2D(latitude: 50.0, longitude: 36.23),
            horizontalAccuracy: 50,
            timestamp: timestamp
        )
    }
}

/// Holds every lookup until the test releases it, and ignores cancellation like a slow network.
private actor GatedGeocoder: ReverseGeocoding {
    private let address: GeocodedAddress
    private(set) var callCount = 0
    private var gate: CheckedContinuation<Void, Never>?
    private var callWaiters: [CheckedContinuation<Void, Never>] = []

    init(address: GeocodedAddress) {
        self.address = address
    }

    func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
        callCount += 1
        callWaiters.forEach { $0.resume() }
        callWaiters.removeAll()
        await withCheckedContinuation { gate = $0 }
        return address
    }

    func waitForCall() async {
        guard callCount == 0 else { return }
        await withCheckedContinuation { callWaiters.append($0) }
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}

private final class FailingOnceGeocoder: ReverseGeocoding {
    private let address: GeocodedAddress
    private let calls = Mutex(0)

    init(address: GeocodedAddress) {
        self.address = address
    }

    var callCount: Int {
        calls.withLock { $0 }
    }

    func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
        let call = calls.withLock { count in
            count += 1
            return count
        }
        if call == 1 {
            throw URLError(.notConnectedToInternet)
        }
        return address
    }
}
