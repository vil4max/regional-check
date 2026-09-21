import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@MainActor
struct RegionSelectionFollowTests {

    // MARK: - REQ-REGION-002 (the stored follow-location flag is vestigial)

    /// 2.x wrote `false` under this key when the driver pinned a region by hand. 3.0 has no pin,
    /// so an install that carries the flag must follow location again, and nothing rewrites it.
    @Test("REQ-REGION-002 a follow-location flag stored as false is ignored and never rewritten")
    func storedFollowFlagIsIgnoredAndLeftUntouched() async throws {
        let suite = "RegionSelectionFollowTests.vestigialFlag.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: SharedStoreKeys.followsLocation)
        let context = makeKharkivTrackingContext(defaults: defaults, cleanUp: {})

        try await context.commitMoveToKharkiv()

        #expect(context.selection.selectedRegion == .kharkiv)
        #expect(context.store.load() == .kharkiv)
        #expect(defaults.object(forKey: SharedStoreKeys.followsLocation) as? Bool == false)
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
        store.save(.kharkiv)
        let selection = RegionSelection(store: store, geocoder: geocoder, now: { clock.withLock { $0 } })
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
        store.save(.lviv)
        let selection = RegionSelection(store: store, geocoder: geocoder, now: { clock.withLock { $0 } })

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

    // MARK: - REQ-REGION-007 (region change notice, no Undo)

    @Test("REQ-REGION-007 a tracker-committed change announces the new region and persists it")
    func trackerCommit_announcesTheNewRegion() async throws {
        let context = try makeKharkivTrackingContext(suite: "announce")
        defer { context.cleanUp() }

        try await context.commitMoveToKharkiv()

        #expect(context.selection.selectedRegion == .kharkiv)
        #expect(context.store.load() == .kharkiv)
        #expect(context.selection.regionChangeNotice?.contains(AlertRegion.kharkiv.title) == true)
    }

    @Test("REQ-REGION-007 dismissing the notice clears it and keeps the region the tracker committed")
    func dismissingTheNotice_keepsTheCommittedRegion() async throws {
        let context = try makeKharkivTrackingContext(suite: "dismiss")
        defer { context.cleanUp() }
        try await context.commitMoveToKharkiv()

        context.selection.dismissRegionChangeNotice()

        #expect(context.selection.regionChangeNotice == nil)
        #expect(context.selection.selectedRegion == .kharkiv)
        #expect(context.store.load() == .kharkiv)
    }

    @Test("REQ-REGION-007 a candidate the tracker has not committed announces nothing")
    func uncommittedCandidate_announcesNothing() async throws {
        let context = try makeKharkivTrackingContext(suite: "candidate")
        defer { context.cleanUp() }

        // A session's first resolve commits at once (REQ-REGION-006), so spend it on Kyiv first;
        // only a later, disagreeing resolve is a candidate.
        let kharkiv = context.geocoder.result
        context.geocoder.result = GeocodedAddress(
            countryCode: "UA",
            cityName: "Київ",
            administrativeAreaName: "Київська область"
        )
        context.selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52))
        try await context.settle { context.geocoder.callCount == 1 }

        context.geocoder.result = kharkiv
        context.advanceClock(100)
        context.selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50.0, longitude: 36.0))
        try await context.settle { context.geocoder.callCount == 2 }
        await Task.yield()

        #expect(context.selection.selectedRegion == .kyivCity)
        #expect(context.selection.regionChangeNotice == nil)
    }

    /// The tracker only announces a change it *commits*. A session's first resolve commits at
    /// once; `commitMoveToKharkiv` still sends a second fix past the throttle, which resolves the
    /// now-current region and changes nothing. The injected clock serves the candidate test.
    private func makeKharkivTrackingContext(suite label: String) throws -> KharkivTrackingContext {
        let suite = "RegionSelectionFollowTests.\(label).\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return makeKharkivTrackingContext(
            defaults: defaults,
            cleanUp: { defaults.removePersistentDomain(forName: suite) }
        )
    }

    private func makeKharkivTrackingContext(
        defaults: UserDefaults,
        cleanUp: @escaping () -> Void
    ) -> KharkivTrackingContext {
        let store = RegionStore(sharedStore: SharedStore(userDefaults: defaults))
        let geocoder = StubGeocoder(result: GeocodedAddress(
            countryCode: "UA",
            cityName: "Харків",
            administrativeAreaName: "Харківська область"
        ))
        let clock = Mutex(Date(timeIntervalSince1970: 10000))
        let selection = RegionSelection(store: store, geocoder: geocoder, now: { clock.withLock { $0 } })
        return KharkivTrackingContext(
            selection: selection,
            store: store,
            geocoder: geocoder,
            // `Mutex` is non-Copyable, so the context holds a closure over the clock, not the clock.
            advanceClock: { seconds in clock.withLock { $0 = $0.addingTimeInterval(seconds) } },
            cleanUp: cleanUp
        )
    }
}

@MainActor
private struct KharkivTrackingContext {
    let selection: RegionSelection
    let store: RegionStore
    let geocoder: StubGeocoder
    let advanceClock: @Sendable (TimeInterval) -> Void
    let cleanUp: () -> Void

    func commitMoveToKharkiv() async throws {
        #expect(selection.selectedRegion == .kyivCity)

        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50.0, longitude: 36.0))
        try await settle { geocoder.callCount == 1 }

        advanceClock(100)
        selection.updateFromLocation(coordinate: CLLocationCoordinate2D(latitude: 50.05, longitude: 36.05))
        try await settle { selection.regionChangeNotice != nil }
    }

    func settle(until condition: () -> Bool) async throws {
        for _ in 0 ..< 200 where !condition() {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
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
