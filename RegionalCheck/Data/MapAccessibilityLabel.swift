import DriveCheckKit
import Foundation

/// The regions under alert in a snapshot, the set the drawn map paints red and its VoiceOver label
/// names.
func mapAlarmRegions(in snapshot: AlertsSnapshot) -> Set<AlertRegion> {
    Set(AlertRegion.allCases.filter { snapshot.status(for: $0) == .alarm })
}

/// VoiceOver label for the drawn map (MAP-native AC-6): one button named by the regions under
/// alert in the same snapshot the map is filled from.
func mapAccessibilityLabel(snapshot: AlertsSnapshot?) -> String {
    guard let snapshot else {
        return String(localized: "map.a11y.unavailable")
    }
    let alarms = mapAlarmRegions(in: snapshot)
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    guard !alarms.isEmpty else {
        return String(localized: "map.a11y.clear")
    }
    let names = alarms.map(\.title).joined(separator: ", ")
    return String(format: String(localized: "map.a11y.alarm"), alarms.count, names)
}
