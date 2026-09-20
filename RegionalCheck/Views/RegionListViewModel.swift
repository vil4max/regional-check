import DriveCheckKit
import Foundation
import Observation

/// Single consumer, so it lives here rather than in `ServiceBoundaries.swift` (ADR 0008). It
/// exposes the current region and nothing that could change it: the region list is read-only
/// (ADR 0015, owner 2026-09-20), and a view model that cannot reach a setter cannot grow one.
@MainActor
protocol CurrentRegionSource: AnyObject {
    var selectedRegion: AlertRegion { get }
}

extension RegionSelection: CurrentRegionSource {}

/// The read-only region list pushed from the Status tab's map (ADR 0015): every region's status,
/// regions under alert first, and the current region marked. Nothing here selects, pins or
/// filters — the region comes from location only.
@MainActor
@Observable
final class RegionListViewModel {
    private let statusSource: any RegionStatusSource
    private let currentRegionSource: any CurrentRegionSource

    init(statusSource: any RegionStatusSource, currentRegionSource: any CurrentRegionSource) {
        self.statusSource = statusSource
        self.currentRegionSource = currentRegionSource
    }

    var currentRegion: AlertRegion {
        currentRegionSource.selectedRegion
    }

    var alarmRegions: [AlertRegion] {
        model.alarmRegions
    }

    var otherRegions: [AlertRegion] {
        model.otherRegions
    }

    var isLoading: Bool {
        statusSource.lastSnapshot == nil
    }

    func status(for region: AlertRegion) -> AlertStatus? {
        model.status(for: region)
    }

    func accessibilityLabel(for region: AlertRegion) -> String {
        let statusText = switch status(for: region) {
        case .alarm:
            String(localized: "Alert Active")
        case .quiet:
            String(localized: "All Clear")
        case nil:
            String(localized: "Checking…")
        }
        let parts = [region.title, statusText] + (region == currentRegion ? [String(localized: "regions.current")] : [])
        return parts.joined(separator: ", ")
    }

    private var model: RegionsListModel {
        RegionsListModel(snapshot: statusSource.lastSnapshot, selected: currentRegion)
    }
}
