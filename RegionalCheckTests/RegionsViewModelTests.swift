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
