import DriveCheckKit
import Foundation
import Observation

@MainActor
protocol RegionStatusSource: AnyObject {
    var lastSnapshot: AlertsSnapshot? { get }
}

@MainActor
protocol RegionSelecting: AnyObject {
    var selectedRegion: AlertRegion { get }
    var followsLocation: Bool { get }
    func pin(_ region: AlertRegion)
    func setFollowsLocation(_ enabled: Bool, immediateFix: LocationFix?)
}

@MainActor
protocol LocationFixProviding: AnyObject {
    var lastFix: LocationFix? { get }
}

@MainActor
protocol PremiumAccessProviding: AnyObject {
    var isPro: Bool { get }
}

protocol SecondaryRegionStore: Sendable {
    func saveSecondaryRegion(_ region: AlertRegion?)
    func loadSecondaryRegion() -> AlertRegion?
}

@MainActor
protocol WidgetReloading: Sendable {
    func reloadAllTimelines()
}

extension StatusController: RegionStatusSource {}
extension RegionSelection: RegionSelecting {}
extension LocationManager: LocationFixProviding {}
extension SubscriptionManager: PremiumAccessProviding {}
extension SharedStore: SecondaryRegionStore {}
extension SharedStore: EntitlementPersisting {}

@MainActor
@Observable
final class RegionsViewModel {
    private let statusSource: any RegionStatusSource
    private let regionSelection: any RegionSelecting
    private let locationProvider: any LocationFixProviding
    private let premiumAccess: any PremiumAccessProviding
    private let secondaryRegionStore: any SecondaryRegionStore
    private let widgetReloader: any WidgetReloading

    init(
        statusSource: any RegionStatusSource,
        regionSelection: any RegionSelecting,
        locationProvider: any LocationFixProviding,
        premiumAccess: any PremiumAccessProviding,
        secondaryRegionStore: any SecondaryRegionStore,
        widgetReloader: any WidgetReloading
    ) {
        self.statusSource = statusSource
        self.regionSelection = regionSelection
        self.locationProvider = locationProvider
        self.premiumAccess = premiumAccess
        self.secondaryRegionStore = secondaryRegionStore
        self.widgetReloader = widgetReloader
    }

    var selectedRegion: AlertRegion {
        regionSelection.selectedRegion
    }

    var followsLocation: Bool {
        regionSelection.followsLocation
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

    var canPinSecondaryRegion: Bool {
        premiumAccess.isPro
    }

    func status(for region: AlertRegion) -> AlertStatus? {
        model.status(for: region)
    }

    func pin(_ region: AlertRegion) {
        regionSelection.pin(region)
    }

    func setFollowsLocation(_ enabled: Bool) {
        regionSelection.setFollowsLocation(
            enabled,
            immediateFix: enabled ? locationProvider.lastFix : nil
        )
    }

    func pinSecondaryRegion(_ region: AlertRegion) {
        guard canPinSecondaryRegion else { return }
        secondaryRegionStore.saveSecondaryRegion(region)
        widgetReloader.reloadAllTimelines()
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
        return "\(region.title), \(statusText)"
    }

    private var model: RegionsListModel {
        RegionsListModel(snapshot: statusSource.lastSnapshot, selected: selectedRegion)
    }
}
