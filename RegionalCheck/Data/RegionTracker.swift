import CoreLocation
import DriveCheckKit
import Foundation
import os

struct LocationFix: Equatable, Sendable {
    let coordinate: CLLocationCoordinate2D
    let horizontalAccuracy: CLLocationAccuracy
    let timestamp: Date

    init(coordinate: CLLocationCoordinate2D, horizontalAccuracy: CLLocationAccuracy, timestamp: Date) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
    }

    init(location: CLLocation) {
        coordinate = location.coordinate
        horizontalAccuracy = location.horizontalAccuracy
        timestamp = location.timestamp
    }

    static func == (lhs: LocationFix, rhs: LocationFix) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.horizontalAccuracy == rhs.horizontalAccuracy
            && lhs.timestamp == rhs.timestamp
    }
}

enum RegionTrackerOutcome: Equatable, Sendable {
    case ignored
    case unchanged
    case candidate(AlertRegion)
    case committed(AlertRegion)
    case outsideUkraine
}

@MainActor
final class RegionTracker {
    private(set) var isOutsideUkraine = false
    static let maxHorizontalAccuracyMeters: CLLocationDistance = 1000
    static let maxFixAge: TimeInterval = 60
    static let geocodeMinInterval: TimeInterval = 60
    static let geocodeMinDistanceMeters: CLLocationDistance = 5000
    static let hysteresisMinDuration: TimeInterval = 90
    static let hysteresisMinDistanceMeters: CLLocationDistance = 5000

    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "RegionTracker")

    private let geocoder: any ReverseGeocoding
    private let now: @Sendable () -> Date

    private var lastGeocodeAt: Date?
    private var lastGeocodeCoordinate: CLLocationCoordinate2D?
    /// The stored region can be days old, and a session's first resolve is the only fresh evidence
    /// there is, so it commits without hysteresis (REQ-REGION-006). The tracker lives as long as
    /// the process, which is what "session" means here.
    private var hasResolvedThisSession = false
    /// A resolve that produced no region leaves nothing to protect by waiting for 5 km.
    private var lastResolveProducedRegion = false
    private var candidateRegion: AlertRegion?
    private var candidateSince: Date?
    private var candidateOrigin: CLLocationCoordinate2D?

    init(
        geocoder: any ReverseGeocoding,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.geocoder = geocoder
        self.now = now
    }

    func evaluate(fix: LocationFix, current: AlertRegion) async -> RegionTrackerOutcome {
        let instant = now()
        guard isAcceptable(fix: fix, now: instant) else {
            return .ignored
        }
        guard shouldGeocode(fix: fix, now: instant) else {
            return .ignored
        }

        return await resolve(fix: fix, current: current, now: instant)
    }

    private func resolve(
        fix: LocationFix,
        current: AlertRegion,
        now: Date
    ) async -> RegionTrackerOutcome {
        lastGeocodeAt = now
        lastGeocodeCoordinate = fix.coordinate
        lastResolveProducedRegion = false

        do {
            guard let address = try await geocoder.reverseGeocode(coordinate: fix.coordinate) else {
                return .unchanged
            }
            guard address.countryCode == "UA" else {
                isOutsideUkraine = true
                clearCandidate()
                return .outsideUkraine
            }
            isOutsideUkraine = false
            guard let resolved = AlertRegionResolver.resolve(
                cityName: address.cityName,
                administrativeArea: address.administrativeAreaName
            ) else {
                Self.log.error("Unresolved reverse-geocode for current region keep")
                return .unchanged
            }
            lastResolveProducedRegion = true
            return consider(resolved: resolved, at: fix.coordinate, now: now, current: current)
        } catch {
            Self.log.error("Reverse geocode failed: \(String(describing: error), privacy: .public)")
            return .ignored
        }
    }

    private func consider(
        resolved: AlertRegion,
        at coordinate: CLLocationCoordinate2D,
        now: Date,
        current: AlertRegion
    ) -> RegionTrackerOutcome {
        let isFirstResolve = !hasResolvedThisSession
        hasResolvedThisSession = true

        if resolved == current {
            clearCandidate()
            return .unchanged
        }

        if isFirstResolve {
            clearCandidate()
            return .committed(resolved)
        }

        if candidateRegion != resolved {
            candidateRegion = resolved
            candidateSince = now
            candidateOrigin = coordinate
            return .candidate(resolved)
        }

        guard let since = candidateSince, let origin = candidateOrigin else {
            candidateRegion = resolved
            candidateSince = now
            candidateOrigin = coordinate
            return .candidate(resolved)
        }

        let elapsed = now.timeIntervalSince(since)
        let distance = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        if elapsed >= Self.hysteresisMinDuration || distance >= Self.hysteresisMinDistanceMeters {
            clearCandidate()
            return .committed(resolved)
        }

        return .candidate(resolved)
    }

    private func isAcceptable(fix: LocationFix, now: Date) -> Bool {
        guard fix.horizontalAccuracy >= 0 else { return false }
        guard fix.horizontalAccuracy <= Self.maxHorizontalAccuracyMeters else { return false }
        guard now.timeIntervalSince(fix.timestamp) <= Self.maxFixAge else { return false }
        return true
    }

    private func shouldGeocode(fix: LocationFix, now: Date) -> Bool {
        guard let lastAt = lastGeocodeAt, let lastCoordinate = lastGeocodeCoordinate else {
            return true
        }
        let elapsed = now.timeIntervalSince(lastAt)
        guard elapsed >= Self.geocodeMinInterval else { return false }
        // The distance condition assumes a settled answer that only movement can change. A pending
        // candidate or a resolve that produced no region is not one: without this a parked driver
        // could never confirm the candidate, and a geocode that failed at launch would not be
        // retried until the car had moved 5 km. The interval still bounds the request rate.
        if candidateRegion != nil || !lastResolveProducedRegion {
            return true
        }
        let distance = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            .distance(from: CLLocation(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude))
        return distance >= Self.geocodeMinDistanceMeters
    }

    private func clearCandidate() {
        candidateRegion = nil
        candidateSince = nil
        candidateOrigin = nil
    }
}
