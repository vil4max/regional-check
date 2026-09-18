import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct RegionsViewModelTests {
    @Test
    func exposesPartitionedRegionsAndStatuses() {
        let snapshot = AlertsSnapshot(
            source: "test",
            serverCachedAt: nil,
            fetchedAt: Date(),
            statuses: [.lviv: .alarm, .kyivCity: .quiet]
        )
        let viewModel = makeViewModel(snapshot: snapshot)

        #expect(viewModel.alarmRegions.contains(.lviv))
        #expect(viewModel.otherRegions.contains(.kyivCity))
        #expect(viewModel.status(for: .lviv) == .alarm)
        #expect(viewModel.status(for: .kyivCity) == .quiet)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func enablingLocationFollowForwardsLatestFix() {
        let fix = LocationFix(
            coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 36),
            horizontalAccuracy: 80,
            timestamp: Date()
        )
        let selection = RegionSelectionSpy()
        let viewModel = makeViewModel(
            selection: selection,
            location: LocationFixStub(lastFix: fix)
        )

        viewModel.setFollowsLocation(true)

        #expect(selection.receivedFollowsLocation == true)
        #expect(selection.receivedImmediateFix == fix)
    }

    @Test
    func secondaryPinPersistsAndReloadsWidgetsForPro() {
        let store = SecondaryRegionStoreSpy()
        let reloader = WidgetReloaderSpy()
        let viewModel = makeViewModel(
            premium: PremiumAccessStub(isPro: true),
            store: store,
            reloader: reloader
        )

        viewModel.pinSecondaryRegion(.lviv)

        #expect(store.savedRegion == .lviv)
        #expect(reloader.reloadCount == 1)
    }

    @Test
    func secondaryPinDoesNothingWithoutPro() {
        let store = SecondaryRegionStoreSpy()
        let reloader = WidgetReloaderSpy()
        let viewModel = makeViewModel(
            premium: PremiumAccessStub(isPro: false),
            store: store,
            reloader: reloader
        )

        viewModel.pinSecondaryRegion(.lviv)

        #expect(store.savedRegion == nil)
        #expect(reloader.reloadCount == 0)
    }

    // MARK: - RD-7 search (REQ-REGION-004)

    @Test
    func searchFiltersBothSectionsByNameAndHidesEmptyAlarmSection() {
        let snapshot = AlertsSnapshot(
            source: "test",
            serverCachedAt: nil,
            fetchedAt: Date(),
            statuses: [.lviv: .alarm, .kharkiv: .alarm, .kyivCity: .quiet, .kyivOblast: .quiet]
        )
        let viewModel = makeViewModel(snapshot: snapshot)
        viewModel.isSearchActive = true
        viewModel.searchText = "Kyiv"

        #expect(viewModel.alarmRegions.isEmpty)
        #expect(Set(viewModel.otherRegions) == [.kyivCity, .kyivOblast])
        #expect(!viewModel.showsNoSearchResults)
    }

    @Test
    func searchKeepsAlphabeticalOrderingOfMatches() {
        let viewModel = makeViewModel()
        viewModel.isSearchActive = true
        viewModel.searchText = "oblast"

        let matched = viewModel.otherRegions
        #expect(matched == matched.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
        #expect(!matched.contains(.kyivCity))
    }

    @Test
    func searchWithNoMatchesShowsNoResultsState() {
        let viewModel = makeViewModel()
        viewModel.isSearchActive = true
        viewModel.searchText = "Zzz"

        #expect(viewModel.alarmRegions.isEmpty)
        #expect(viewModel.otherRegions.isEmpty)
        #expect(viewModel.showsNoSearchResults)
    }

    @Test
    func inactiveSearchNeverFilters() {
        let viewModel = makeViewModel()
        viewModel.searchText = "Zzz" // set but search not active

        #expect(viewModel.otherRegions.count == AlertRegion.allCases.count)
        #expect(!viewModel.showsNoSearchResults)
    }

    @Test
    func selectingASearchResultPinsAndStopsFollowing() {
        let selection = RegionSelectionSpy()
        let viewModel = makeViewModel(selection: selection)
        viewModel.isSearchActive = true
        viewModel.searchText = "Lviv"

        guard let result = viewModel.otherRegions.first else {
            Issue.record("expected a search result for 'Lviv'")
            return
        }
        viewModel.pin(result)

        #expect(viewModel.selectedRegion == .lviv)
        #expect(selection.followsLocation == false)
    }

    @Test
    func deactivatingSearchClearsTheQuery() {
        let viewModel = makeViewModel()
        viewModel.isSearchActive = true
        viewModel.searchText = "Lviv"

        viewModel.setSearchActive(false)

        #expect(viewModel.searchText.isEmpty)
        #expect(!viewModel.isSearchActive)
    }

    private func makeViewModel(
        snapshot: AlertsSnapshot? = nil,
        selection: RegionSelectionSpy? = nil,
        location: LocationFixStub? = nil,
        premium: PremiumAccessStub? = nil,
        store: SecondaryRegionStoreSpy? = nil,
        reloader: WidgetReloaderSpy? = nil
    ) -> RegionsViewModel {
        RegionsViewModel(
            statusSource: RegionStatusStub(lastSnapshot: snapshot),
            regionSelection: selection ?? RegionSelectionSpy(),
            locationProvider: location ?? LocationFixStub(lastFix: nil),
            premiumAccess: premium ?? PremiumAccessStub(isPro: false),
            secondaryRegionStore: store ?? SecondaryRegionStoreSpy(),
            widgetReloader: reloader ?? WidgetReloaderSpy()
        )
    }
}

@MainActor
private final class RegionStatusStub: RegionStatusSource {
    let lastSnapshot: AlertsSnapshot?

    init(lastSnapshot: AlertsSnapshot?) {
        self.lastSnapshot = lastSnapshot
    }
}

@MainActor
private final class RegionSelectionSpy: RegionSelecting {
    var selectedRegion = AlertRegion.kyivCity
    var followsLocation = true
    private(set) var receivedFollowsLocation: Bool?
    private(set) var receivedImmediateFix: LocationFix?

    func pin(_ region: AlertRegion) {
        selectedRegion = region
        followsLocation = false // mirrors RegionSelection.pin(_:)
    }

    func setFollowsLocation(_ enabled: Bool, immediateFix: LocationFix?) {
        followsLocation = enabled
        receivedFollowsLocation = enabled
        receivedImmediateFix = immediateFix
    }
}

@MainActor
private final class LocationFixStub: LocationFixProviding {
    let lastFix: LocationFix?

    init(lastFix: LocationFix?) {
        self.lastFix = lastFix
    }
}

@MainActor
private final class PremiumAccessStub: PremiumAccessProviding {
    let isPro: Bool

    init(isPro: Bool) {
        self.isPro = isPro
    }
}

private final class SecondaryRegionStoreSpy: SecondaryRegionStore, @unchecked Sendable {
    private(set) var savedRegion: AlertRegion?
    var stubbedLoadRegion: AlertRegion?

    func saveSecondaryRegion(_ region: AlertRegion?) {
        savedRegion = region
    }

    func loadSecondaryRegion() -> AlertRegion? {
        stubbedLoadRegion
    }
}

private final class WidgetReloaderSpy: WidgetReloading, @unchecked Sendable {
    private(set) var reloadCount = 0

    func reloadAllTimelines() {
        reloadCount += 1
    }
}
