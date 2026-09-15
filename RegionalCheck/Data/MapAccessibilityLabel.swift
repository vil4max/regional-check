import DriveCheckKit
import Foundation

/// VoiceOver label for the upstream raster map, derived from the shared JSON
/// snapshot. The image itself carries no region semantics, so the snapshot is
/// the only honest source for what the picture means.
func mapAccessibilityLabel(snapshot: AlertsSnapshot?) -> String {
    guard let snapshot else {
        return String(localized: "map.a11y.unavailable")
    }
    let alarms = AlertRegion.allCases
        .filter { snapshot.status(for: $0) == .alarm }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    guard !alarms.isEmpty else {
        return String(localized: "map.a11y.clear")
    }
    let names = alarms.map(\.title).joined(separator: ", ")
    return String(format: String(localized: "map.a11y.alarm"), alarms.count, names)
}
