import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@MainActor
struct RegionSelectionFollowTests {
    @Test
    func pin_disablesFollowAndSavesRegion() throws {
        let suite = "RegionSelectionFollowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
        let selection = RegionSelection(store: store, geocoder: StubGeocoder())

        #expect(selection.followsLocation == true)
        selection.pin(.lviv)
        #expect(selection.followsLocation == false)
        #expect(selection.selectedRegion == .lviv)
        #expect(store.load() == .lviv)
        #expect(store.loadFollowsLocation() == false)
    }

    @Test
    func setFollowsLocation_persists() throws {
        let suite = "RegionSelectionFollowTests.persist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
        let selection = RegionSelection(store: store, geocoder: StubGeocoder())

        selection.setFollowsLocation(false)
        let restored = RegionSelection(store: store, geocoder: StubGeocoder())
        #expect(restored.followsLocation == false)
    }

    @Test
    func setFollowsLocation_enabledAppliesImmediateGeoRegion() async throws {
        let suite = "RegionSelectionFollowTests.resumeGeo.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
        let geocoder = StubGeocoder(result: GeocodedAddress(
            countryCode: "UA",
            cityName: "Харків",
            administrativeAreaName: "Харківська область"
        ))
        let selection = RegionSelection(store: store, geocoder: geocoder)
        selection.pin(.lviv)
        #expect(selection.selectedRegion == .lviv)

        let fix = LocationFix(
            coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 36),
            horizontalAccuracy: 80,
            timestamp: Date()
        )
        selection.setFollowsLocation(true, immediateFix: fix)
        for _ in 0 ..< 200 where selection.selectedRegion != .kharkiv {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(selection.followsLocation == true)
        #expect(selection.selectedRegion == .kharkiv)
        #expect(geocoder.callCount == 1)
    }

    // MARK: - REQ-REGION-008 (outside Ukraine keeps the last region)

    @Test("REQ-REGION-008 outside Ukraine keeps the last selected region and shows the sheet once")
    func outsideUkraine_keepsLastRegionAndShowsSheetOnce() async throws {
        let suite = "RegionSelectionFollowTests.outside.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
        let geocoder = StubGeocoder()
        // A controllable clock: `updateFromLocation`'s throttle (60 s / 5 km) otherwise blocks
        // the test's second geocode, which happens far less than 60 real seconds after the first.
        let clock = Mutex(Date(timeIntervalSince1970: 10000))
        let selection = RegionSelection(store: store, geocoder: geocoder, now: { clock.withLock { $0 } })
        selection.pin(.kharkiv)
        // `pin` disables follow (REQ-REGION-003); `updateFromLocation` no-ops while it's
        // disabled, so re-enable it to exercise location-driven transitions below.
        selection.setFollowsLocation(true)
        #expect(selection.shouldShowOutsideUkraineSheet == false)

        geocoder.result = GeocodedAddress(countryCode: "PL", cityName: nil, administrativeAreaName: nil)
        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 20))
        for _ in 0 ..< 200 where !selection.isOutsideUkraine {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }

        #expect(selection.isOutsideUkraine)
        #expect(selection.selectedRegion == .kharkiv, "the last region stays selected while outside")
        #expect(selection.shouldShowOutsideUkraineSheet)

        // Does not repeat while the location stays outside — a later fix, far enough away and
        // late enough to clear the geocode throttle, still resolves outside.
        selection.acknowledgeOutsideUkraineSheet()
        clock.withLock { $0 = $0.addingTimeInterval(120) }
        geocoder.result = GeocodedAddress(countryCode: "PL", cityName: nil, administrativeAreaName: nil)
        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 51, longitude: 21))
        for _ in 0 ..< 200 where geocoder.callCount < 2 {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(geocoder.callCount == 2, "the throttle must actually clear for this to test anything")
        #expect(selection.shouldShowOutsideUkraineSheet == false)
    }

    @Test("REQ-REGION-008 no previous region falls back to Kyiv city, not left unset, while outside")
    func outsideUkraine_noPreviousRegion_fallsBackToKyivCity() async throws {
        let suite = "RegionSelectionFollowTests.outsideNoPrevious.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
        let geocoder = StubGeocoder(result: GeocodedAddress(
            countryCode: "PL",
            cityName: nil,
            administrativeAreaName: nil
        ))
        let selection = RegionSelection(store: store, geocoder: geocoder)
        #expect(
            selection.selectedRegion == .kyivCity,
            "init falls back to Kyiv city when the store has no prior region"
        )

        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 20))
        for _ in 0 ..< 200 where !selection.isOutsideUkraine {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(selection.selectedRegion == .kyivCity)
    }

    @Test("REQ-REGION-008 the sheet shows again after returning inside then leaving Ukraine again")
    func outsideUkraine_showsAgainAfterANewTransition() async throws {
        let suite = "RegionSelectionFollowTests.outsideAgain.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
        let geocoder = StubGeocoder()
        let clock = Mutex(Date(timeIntervalSince1970: 20000))
        let selection = RegionSelection(store: store, geocoder: geocoder, now: { clock.withLock { $0 } })
        selection.pin(.lviv)
        selection.setFollowsLocation(true)

        geocoder.result = GeocodedAddress(countryCode: "PL", cityName: nil, administrativeAreaName: nil)
        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 20))
        for _ in 0 ..< 200 where !selection.isOutsideUkraine {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        selection.acknowledgeOutsideUkraineSheet()

        clock.withLock { $0 = $0.addingTimeInterval(120) }
        geocoder.result = GeocodedAddress(
            countryCode: "UA",
            cityName: "Львів",
            administrativeAreaName: "Львівська область"
        )
        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 49.8, longitude: 24))
        for _ in 0 ..< 200 where selection.isOutsideUkraine {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(geocoder.callCount == 2)
        #expect(selection.shouldShowOutsideUkraineSheet == false)

        clock.withLock { $0 = $0.addingTimeInterval(120) }
        geocoder.result = GeocodedAddress(countryCode: "PL", cityName: nil, administrativeAreaName: nil)
        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 20))
        for _ in 0 ..< 200 where !selection.isOutsideUkraine {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(geocoder.callCount == 3)
        #expect(selection.shouldShowOutsideUkraineSheet, "a new inside→outside transition shows the sheet again")
    }

    @Test
    func updateFromLocation_ignoredWhenPinned() async throws {
        let suite = "RegionSelectionFollowTests.pinIgnore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
        let geocoder = StubGeocoder(result: GeocodedAddress(
            countryCode: "UA",
            cityName: "Харків",
            administrativeAreaName: "Харківська область"
        ))
        let selection = RegionSelection(store: store, geocoder: geocoder)
        selection.pin(.lviv)
        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 36))
        await Task.yield()
        await Task.yield()
        #expect(selection.selectedRegion == .lviv)
        #expect(geocoder.callCount == 0)
    }
}

private final class StubGeocoder: ReverseGeocoding, @unchecked Sendable {
    var result: GeocodedAddress?
    private(set) var callCount = 0

    init(result: GeocodedAddress? = nil) {
        self.result = result
    }

    func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
        callCount += 1
        return result
    }
}
