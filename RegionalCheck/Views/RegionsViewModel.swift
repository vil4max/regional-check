import DriveCheckKit
import Foundation
import Observation

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

    /// RD-7: search state. Lives here, not as view `@State`, because `MainTabView` rebuilds
    /// `RegionsView` on every tab switch (a plain content `switch`, not `TabView` — see
    /// `MainTabView.body`); keeping it on the `AppContainer`-owned view model is what lets an
    /// in-progress search survive switching to Status and back.
    var isSearchActive = false
    var searchText = ""

    var alarmRegions: [AlertRegion] {
        filtered(model.alarmRegions)
    }

    var otherRegions: [AlertRegion] {
        filtered(model.otherRegions)
    }

    /// `true` once search is active and the query matches nothing in either section
    /// (states.md row 5b): distinct from "no alerts right now", which never shows this state.
    var showsNoSearchResults: Bool {
        isSearchActive && !searchText.isEmpty && alarmRegions.isEmpty && otherRegions.isEmpty
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

    /// Opens search — the RD-4 round action button's target on the Regions tab.
    func activateSearch() {
        isSearchActive = true
    }

    /// The `.searchable(isPresented:)` binding's setter: clears the query so the next activation
    /// starts fresh rather than reopening onto a stale filter.
    func setSearchActive(_ active: Bool) {
        isSearchActive = active
        if !active {
            searchText = ""
        }
    }

    private func filtered(_ regions: [AlertRegion]) -> [AlertRegion] {
        guard isSearchActive, !searchText.isEmpty else { return regions }
        return regions.filter { RegionSearchMatcher.matches($0, query: searchText) }
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
