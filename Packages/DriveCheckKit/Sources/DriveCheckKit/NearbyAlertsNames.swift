import Foundation

/// REQ-SURF-005: the neighbours of a region under alert and the short list of their names. One rule
/// for every surface that names them: the phone's reason line, CarPlay's nearby row and the Siri
/// answer (STATUS-two-states), so an order or wording change is made once.
public enum NearbyAlertsNames {
    /// At most this many names, then "+N" for the rest, so the note stays readable at a glance.
    public static let shownNames = 2

    /// The neighbours of `region` under alert, in `NearbyRegionPolicy`'s order; empty without a
    /// snapshot.
    public static func regions(near region: AlertRegion, snapshot: AlertsSnapshot?) -> [AlertRegion] {
        guard let snapshot else { return [] }
        let alerts = AlertRegion.allCases.filter { snapshot.status(for: $0) == .alarm }
        return NearbyRegionPolicy.activeAlerts(near: region, among: alerts)
    }

    public static func names(_ regions: [AlertRegion]) -> String {
        let shown = regions.prefix(shownNames).map(\.title).joined(separator: ", ")
        let remaining = regions.count - min(shownNames, regions.count)
        guard remaining > 0 else { return shown }
        return String(format: String(localized: "nearby.names_more", bundle: .module), shown, remaining)
    }
}
