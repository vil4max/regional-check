import DriveCheckKit
import Foundation

/// MAP-native: the fill of one unit of the drawn map, from the same snapshot as the status above it.
enum AlertMapFill: Equatable {
    case alarm
    case quiet
    case noData

    /// Crimea and Sevastopol have no status in the app, so they are always no data (owner: grey,
    /// as part of Ukraine); a region the snapshot does not carry is no data too, never quiet.
    static func fill(for unit: MapUnit, snapshot: AlertsSnapshot?) -> AlertMapFill {
        guard case .region(let region) = unit, let status = snapshot?.status(for: region) else { return .noData }
        return status == .alarm ? .alarm : .quiet
    }

    /// Stale data draws the same fills dimmed (owner: «Приглушить»): readable, but not live.
    static func opacity(isStale: Bool) -> Double {
        isStale ? 0.45 : 1
    }
}
