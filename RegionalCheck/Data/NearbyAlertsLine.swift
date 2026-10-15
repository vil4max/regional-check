import DriveCheckKit
import Foundation

/// REQ-SURF-005: the one line naming the neighbouring regions under alert, shared by the CarPlay
/// Status row and the phone Status tab so a wording or ordering change is made once. One format
/// key per line, so translators can reorder it.
enum NearbyAlertsLine {
    /// At most this many names, then a "+N" badge for the rest, so the line stays readable at a
    /// glance however many neighbours are under alert.
    static let shownNames = 2

    /// `nil` when no neighbour is under alert.
    @MainActor
    static func text(region: AlertRegion, snapshot: AlertsSnapshot?) -> String? {
        guard let snapshot else { return nil }
        let alerts = AlertRegion.allCases.filter { snapshot.status(for: $0) == .alarm }
        let nearby = NearbyRegionPolicy.activeAlerts(near: region, among: alerts)
        guard !nearby.isEmpty else { return nil }
        return String(format: String(localized: "driver.status.nearby_line"), names(nearby))
    }

    @MainActor
    static func names(_ regions: [AlertRegion]) -> String {
        let shown = regions.prefix(shownNames).map(\.title).joined(separator: ", ")
        let remaining = regions.count - min(shownNames, regions.count)
        guard remaining > 0 else { return shown }
        return String(format: String(localized: "driver.status.nearby_names_more"), shown, remaining)
    }
}
