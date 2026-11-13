import DriveCheckKit
import Foundation

struct RegionsListModel: Equatable, Sendable {
    let alarmRegions: [AlertRegion]
    let otherRegions: [AlertRegion]
    private let statuses: [AlertRegion: AlertStatus]

    init(snapshot: AlertsSnapshot?) {
        if let snapshot {
            statuses = snapshot.statuses
            let alarms = AlertRegion.allCases.filter { snapshot.status(for: $0) == .alarm }
            let others = AlertRegion.allCases.filter { snapshot.status(for: $0) != .alarm }
            alarmRegions = Self.sortedByTitle(alarms)
            otherRegions = Self.sortedByTitle(others)
        } else {
            statuses = [:]
            alarmRegions = []
            otherRegions = Self.sortedByTitle(AlertRegion.allCases)
        }
    }

    func status(for region: AlertRegion) -> AlertStatus? {
        statuses[region]
    }

    private static func sortedByTitle(_ regions: [AlertRegion]) -> [AlertRegion] {
        regions.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
