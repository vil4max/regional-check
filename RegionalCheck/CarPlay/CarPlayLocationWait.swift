import CoreLocation
import Foundation

/// Bounded wait for the first location fix of a CarPlay refresh cycle, so the first loaded
/// snapshot uses the location-derived region. On timeout the persisted region from the previous
/// session stays in effect. Without location permission there is nothing to wait for.
@MainActor
struct CarPlayLocationWait {
    static let timeout: Duration = .seconds(5)
    static let pollInterval: Duration = .milliseconds(250)

    let location: any CarPlayLocationSource
    let sleep: (Duration) async throws -> Void

    func run() async {
        guard location.lastFix == nil else { return }
        guard [.authorizedWhenInUse, .authorizedAlways].contains(location.authorizationStatus) else { return }
        var waited: Duration = .zero
        while location.lastFix == nil, waited < Self.timeout {
            do {
                try await sleep(Self.pollInterval)
            } catch {
                return
            }
            waited += Self.pollInterval
        }
        if location.lastFix == nil {
            CarPlayLog.lifecycle.info("Location wait timed out; using persisted region")
        }
    }
}
