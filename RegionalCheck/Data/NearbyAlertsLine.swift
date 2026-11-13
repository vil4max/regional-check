import DriveCheckKit
import Foundation

/// REQ-SURF-005: CarPlay's nearby row and the phone's reason line, over the one names rule the
/// Siri answer shares (`NearbyAlertsNames`). One format key per line, so translators can reorder it.
enum NearbyAlertsLine {
    /// `nil` when no neighbour is under alert.
    @MainActor
    static func text(region: AlertRegion, snapshot: AlertsSnapshot?) -> String? {
        let nearby = regions(near: region, snapshot: snapshot)
        guard !nearby.isEmpty else { return nil }
        return String(format: String(localized: "driver.status.nearby_line"), names(nearby))
    }

    /// The neighbours of `region` under alert, in `NearbyRegionPolicy`'s order; empty without a
    /// snapshot.
    static func regions(near region: AlertRegion, snapshot: AlertsSnapshot?) -> [AlertRegion] {
        NearbyAlertsNames.regions(near: region, snapshot: snapshot)
    }

    static func names(_ regions: [AlertRegion]) -> String {
        NearbyAlertsNames.names(regions)
    }
}
