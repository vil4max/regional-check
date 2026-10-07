import CoreLocation
import DriveCheckKit
import Foundation
import Observation
@testable import RegionalCheck
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct RegionOwnerIntegrationTests {
    @Test("REQ-REGION-007 the region is persisted once before observers run")
    func commitPersistsBeforeObservationAndWidgetReload() async throws {
        let suite = "RegionOwnerIntegrationTests.\(UUID().uuidString)"
        let defaults = try #require(RegionCountingDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let shared = SharedStore(userDefaults: defaults, legacyDefaults: defaults)
        let regions = RegionSelection(
            store: RegionStore(sharedStore: shared),
            geocoder: OwnerKharkivGeocoder(),
            now: { FixtureNetwork.servedAt }
        )
        let network = FixtureNetwork()
        shared.saveSnapshot(network.snapshot(fetchedAt: FixtureNetwork.servedAt))
        let queue = RegionFollowQueue()
        let reloader = RegionReloadSpy()
        let status = StatusController(
            region: .kyivCity,
            provider: UbillingProvider(httpClient: network, now: { FixtureNetwork.servedAt }),
            environmentProvider: FixtureRefreshEnvironment(),
            persistence: shared,
            widgetReloader: reloader,
            now: { FixtureNetwork.servedAt },
            scheduleRegionChange: { change in
                // This runs synchronously in willSet, before any queued follower can hide bad ordering.
                #expect(shared.loadRegion() == .kharkiv)
                queue.enqueue(change)
            }
        )
        status.follow(regions)
        #expect(defaults.regionWrites == 0)
        #expect(shared.loadRegion() == nil)

        await commitMove(regions)
        #expect(defaults.regionWrites == 1)
        queue.drain()
        #expect(status.currentRegion == regions.selectedRegion)
        #expect(status.state.phase == .alarm)
        #expect(reloader.reloadCount == 1)
        await reloader.waitForCount(2)

        #expect(shared.loadRegion() == .kharkiv)
        #expect(defaults.regionWrites == 1)
        #expect(network.alertRequestCount == 1)
        #expect(reloader.reloadCount == 2)
    }

    @Test("REQ-REGION-006 AppContainer wires its sole region follower without a phone or CarPlay session")
    func containerFollowsRegionWithoutSurfaceAdapters() async throws {
        let suite = "RegionOwnerIntegrationTests.container.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let shared = SharedStore(userDefaults: defaults, legacyDefaults: defaults)
        let regions = RegionSelection(
            store: RegionStore(sharedStore: shared),
            geocoder: OwnerKharkivGeocoder(),
            now: { FixtureNetwork.servedAt }
        )
        let network = FixtureNetwork()
        let reloader = RegionReloadSpy()
        let app = AppContainer(
            provider: UbillingProvider(httpClient: network, now: { FixtureNetwork.servedAt }),
            location: FixtureLocationManager(),
            regions: regions,
            subscription: SubscriptionManager(
                service: FixtureSubscriptionService(isPro: false, now: FixtureNetwork.servedAt),
                cache: EntitlementCache(userDefaults: defaults),
                userDefaults: defaults,
                entitlementPersistence: shared,
                widgetReloader: reloader
            ),
            statusPersistence: shared,
            widgetReloader: reloader,
            mapHTTPClient: network,
            statusDetailsSummarizer: DeterministicStatusDetailsProvider(),
            refreshEnvironment: FixtureRefreshEnvironment(),
            now: { FixtureNetwork.servedAt },
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: false)
        )

        await commitMove(regions)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while app.status.currentRegion != .kharkiv, ContinuousClock.now < deadline {
            await Task.yield()
        }
        try #require(app.status.currentRegion == .kharkiv)
        await reloader.waitForCount(2)

        #expect(app.status.regionTitle == AlertRegion.kharkiv.title)
        #expect(network.alertRequestCount == 1)
        #expect(reloader.reloadCount == 2)
    }

    private func commitMove(_ regions: RegionSelection) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = regions.selectedRegion
            } onChange: {
                continuation.resume()
            }
            regions.updateFromLocation(
                fix: LocationFix(
                    coordinate: CLLocationCoordinate2D(latitude: 50, longitude: 36),
                    horizontalAccuracy: 40,
                    timestamp: FixtureNetwork.servedAt
                ))
        }
        #expect(regions.selectedRegion == .kharkiv)
    }
}

private struct OwnerKharkivGeocoder: ReverseGeocoding {
    func reverseGeocode(coordinate _: CLLocationCoordinate2D) async throws -> GeocodedAddress? {
        GeocodedAddress(countryCode: "UA", cityName: "Харків", administrativeAreaName: "Харківська область")
    }
}

// UserDefaults owns its synchronization; the additional test counter is protected by a mutex.
private final class RegionCountingDefaults: UserDefaults, @unchecked Sendable {
    private let writes = Mutex(0)
    var regionWrites: Int { writes.withLock { $0 } }

    override func set(_ value: Any?, forKey key: String) {
        if key == SharedStoreKeys.region { writes.withLock { $0 += 1 } }
        super.set(value, forKey: key)
    }
}
