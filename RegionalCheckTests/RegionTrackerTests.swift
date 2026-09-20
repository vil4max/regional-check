import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@MainActor
struct RegionTrackerTests {
    @Test
    func returningToUkraineClearsOutsideMarkerEvenInSameRegion() async {
        let geocoder = CountingGeocoder(region: .lviv)
        let now = Mutex(Date(timeIntervalSince1970: 1000))
        let tracker = RegionTracker(geocoder: geocoder, now: { now.withLock { $0 } })
        let abroad = makeFix(lat: 50, lon: 20, accuracy: 50, timestamp: now.withLock { $0 })
        geocoder.countryCode = "PL"
        #expect(await tracker.evaluate(fix: abroad, current: .lviv) == .outsideUkraine)
        #expect(tracker.isOutsideUkraine)

        // Far and late enough to clear the geocode throttle, or the second fix is never resolved.
        now.withLock { $0 = $0.addingTimeInterval(120) }
        let home = makeFix(lat: 49.8, lon: 24, accuracy: 50, timestamp: now.withLock { $0 })
        geocoder.countryCode = "UA"
        #expect(await tracker.evaluate(fix: home, current: .lviv) == .unchanged)
        #expect(!tracker.isOutsideUkraine)
    }

    @Test("REQ-REGION-005 stale or inaccurate location fixes are ignored")
    func ignoresStaleOrInaccurateFixes() async {
        let geocoder = CountingGeocoder(region: .kharkiv)
        let now = Date(timeIntervalSince1970: 1000)
        let tracker = RegionTracker(geocoder: geocoder, now: { now })

        let stale = makeFix(lat: 50, lon: 36, accuracy: 100, timestamp: now.addingTimeInterval(-120))
        #expect(await tracker.evaluate(fix: stale, current: .kyivCity) == .ignored)
        #expect(geocoder.callCount == 0)

        let inaccurate = makeFix(lat: 50, lon: 36, accuracy: 2000, timestamp: now)
        #expect(await tracker.evaluate(fix: inaccurate, current: .kyivCity) == .ignored)
        #expect(geocoder.callCount == 0)
    }

    @Test("REQ-REGION-005 geocoding is throttled by both interval and distance")
    func throttlesGeocodeUntilIntervalAndDistance() async {
        let geocoder = CountingGeocoder(region: .kharkiv)
        let now = Mutex(Date(timeIntervalSince1970: 2000))
        let tracker = RegionTracker(geocoder: geocoder, now: { now.withLock { $0 } })

        let first = makeFix(lat: 50.0, lon: 36.0, accuracy: 50, timestamp: now.withLock { $0 })
        #expect(await tracker.evaluate(fix: first, current: .kyivCity) == .candidate(.kharkiv))
        #expect(geocoder.callCount == 1)

        now.withLock { $0 = $0.addingTimeInterval(30) }
        let near = makeFix(lat: 50.001, lon: 36.001, accuracy: 50, timestamp: now.withLock { $0 })
        #expect(await tracker.evaluate(fix: near, current: .kyivCity) == .ignored)
        #expect(geocoder.callCount == 1)
    }

    @Test("REQ-REGION-006 a new region commits only after the hysteresis duration")
    func commitsAfterHysteresisDuration() async {
        let geocoder = CountingGeocoder(region: .kharkiv)
        let now = Mutex(Date(timeIntervalSince1970: 3000))
        let tracker = RegionTracker(geocoder: geocoder, now: { now.withLock { $0 } })

        let first = makeFix(lat: 50.0, lon: 36.0, accuracy: 50, timestamp: now.withLock { $0 })
        #expect(await tracker.evaluate(fix: first, current: .kyivCity) == .candidate(.kharkiv))

        now.withLock { $0 = $0.addingTimeInterval(100) }
        let later = makeFix(lat: 50.05, lon: 36.05, accuracy: 50, timestamp: now.withLock { $0 })
        #expect(await tracker.evaluate(fix: later, current: .kyivCity) == .committed(.kharkiv))
    }

    @Test("REQ-REGION-006 a disagreeing resolve resets the candidate region")
    func disagreeingResolveResetsCandidate() async {
        let geocoder = CountingGeocoder(region: .kharkiv)
        let now = Mutex(Date(timeIntervalSince1970: 4000))
        let tracker = RegionTracker(geocoder: geocoder, now: { now.withLock { $0 } })

        let first = makeFix(lat: 50, lon: 36, accuracy: 40, timestamp: now.withLock { $0 })
        #expect(await tracker.evaluate(fix: first, current: .kyivCity) == .candidate(.kharkiv))

        now.withLock { $0 = $0.addingTimeInterval(120) }
        geocoder.resolved = .lviv
        let second = makeFix(lat: 50.2, lon: 36.2, accuracy: 40, timestamp: now.withLock { $0 })
        #expect(await tracker.evaluate(fix: second, current: .kyivCity) == .candidate(.lviv))
    }

    @Test("REQ-REGION-006 resolving the current region again clears the candidate")
    func sameRegionResolutionClearsCandidate() async {
        let geocoder = CountingGeocoder(region: .kyivCity)
        let now = Mutex(Date(timeIntervalSince1970: 5000))
        let tracker = RegionTracker(geocoder: geocoder, now: { now.withLock { $0 } })

        geocoder.resolved = .kharkiv
        let first = makeFix(lat: 50, lon: 36, accuracy: 40, timestamp: now.withLock { $0 })
        #expect(await tracker.evaluate(fix: first, current: .kyivCity) == .candidate(.kharkiv))

        now.withLock { $0 = $0.addingTimeInterval(120) }
        geocoder.resolved = .kyivCity
        let second = makeFix(lat: 50.2, lon: 36.2, accuracy: 40, timestamp: now.withLock { $0 })
        #expect(await tracker.evaluate(fix: second, current: .kyivCity) == .unchanged)
    }

    private func makeFix(
        lat: CLLocationDegrees,
        lon: CLLocationDegrees,
        accuracy: CLLocationAccuracy,
        timestamp: Date
    ) -> LocationFix {
        LocationFix(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            horizontalAccuracy: accuracy,
            timestamp: timestamp
        )
    }
}

@MainActor
private final class CountingGeocoder: ReverseGeocoding, @unchecked Sendable {
    var countryCode = "UA"
    var resolved: AlertRegion
    private(set) var callCount = 0

    init(region: AlertRegion) {
        resolved = region
    }

    func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
        callCount += 1
        if countryCode != "UA" {
            return GeocodedAddress(countryCode: countryCode, cityName: nil, administrativeAreaName: nil)
        }
        switch resolved {
        case .kyivCity:
            return GeocodedAddress(countryCode: "UA", cityName: "Київ", administrativeAreaName: "Київська область")
        case .kharkiv:
            return GeocodedAddress(
                countryCode: "UA",
                cityName: "Харків",
                administrativeAreaName: "Харківська область"
            )
        case .lviv:
            return GeocodedAddress(
                countryCode: "UA",
                cityName: "Львів",
                administrativeAreaName: "Львівська область"
            )
        default:
            return GeocodedAddress(countryCode: "UA", cityName: nil, administrativeAreaName: resolved.apiKey)
        }
    }
}
