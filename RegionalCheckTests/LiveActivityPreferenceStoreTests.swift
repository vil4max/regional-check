import DriveCheckKit
import Foundation
import Observation
@testable import RegionalCheck
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct LiveActivityPreferenceStoreTests {
    @Test("REQ-SURF-007 the stored Live Activity choice survives a new store with the original key and default")
    func storedChoiceSurvivesNewStore() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = LiveActivityPreferenceStore(userDefaults: defaults)
            #expect(store.isEnabled)
            #expect(defaults.object(forKey: "subscription.liveActivity.enabled") == nil)

            store.setEnabled(false)

            #expect(defaults.object(forKey: "subscription.liveActivity.enabled") as? Bool == false)
            #expect(!LiveActivityPreferenceStore(userDefaults: defaults).isEnabled)
            defaults.set(true, forKey: "subscription.liveActivity.enabled")
            #expect(LiveActivityPreferenceStore(userDefaults: defaults).isEnabled)
        }
    }

    @Test("REQ-SURF-008 only changed preferences are announced, while every setter persists")
    func repeatsPersistWithoutExtraNotifications() async throws {
        let suite = "LiveActivityPreferenceStoreTests.repeats.\(UUID().uuidString)"
        let defaults = try #require(PreferenceCountingDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var store: LiveActivityPreferenceStore? = LiveActivityPreferenceStore(userDefaults: defaults)
        let stream = try #require(store).changes()

        store?.setEnabled(false)
        store?.setEnabled(false)
        store?.setEnabled(true)
        store = nil

        var notifications = 0
        for await _ in stream { notifications += 1 }
        #expect(notifications == 2, "Includes the final true sentinel, but no initial or repeated-value event")
        #expect(defaults.preferenceWrites == 3)
        #expect(defaults.bool(forKey: "subscription.liveActivity.enabled"))
    }

    @Test("REQ-SURF-008 the observable preference invalidates the Details switch")
    func detailsSwitchTracksTheRealStore() {
        TestDefaults.withTemporaryDefaults { defaults in
            let store = LiveActivityPreferenceStore(userDefaults: defaults)
            let details = DetailsViewModel(
                location: FixtureLocationManager(),
                liveActivityPreference: store,
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
                setLiveActivityEnabled: { store.setEnabled($0) }
            )
            let storeInvalidated = Mutex(false)
            let switchInvalidated = Mutex(false)
            withObservationTracking {
                #expect(store.isEnabled)
            } onChange: {
                storeInvalidated.withLock { $0 = true }
            }
            withObservationTracking {
                #expect(details.isLiveActivitySwitchOn)
            } onChange: {
                switchInvalidated.withLock { $0 = true }
            }

            store.setEnabled(false)

            #expect(storeInvalidated.withLock { $0 })
            #expect(switchInvalidated.withLock { $0 })
            #expect(!details.isLiveActivitySwitchOn)
        }
    }

    @Test("REQ-SURF-007 AppContainer's default preference reads and writes standard defaults")
    func containerDefaultPreservesTheProductionSuite() {
        let key = "subscription.liveActivity.enabled"
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: key)
        defer {
            if let previous { defaults.set(previous, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.set(false, forKey: key)
        TestDefaults.withTemporaryDefaults { isolatedDefaults in
            let network = FixtureNetwork()
            let shared = SharedStore(userDefaults: isolatedDefaults, legacyDefaults: isolatedDefaults)
            let app = AppContainer(
                provider: UbillingProvider(httpClient: network),
                location: FixtureLocationManager(),
                regions: RegionSelection(store: RegionStore(sharedStore: shared), geocoder: FixtureReverseGeocoder()),
                subscription: SubscriptionManager(
                    service: FixtureSubscriptionService(isPro: false, now: FixtureNetwork.servedAt),
                    cache: EntitlementCache(userDefaults: isolatedDefaults),
                    entitlementPersistence: shared,
                    widgetReloader: TestWidgetReloader()
                ),
                statusPersistence: shared,
                widgetReloader: TestWidgetReloader(),
                mapHTTPClient: network,
                statusDetailsSummarizer: DeterministicStatusDetailsProvider(),
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true)
            )
            #expect(!app.liveActivityPreference.isEnabled)
            #expect(!app.detailsViewModel.isLiveActivitySwitchOn)
            #expect(!app.liveActivity.canRunActivity)

            app.mainTabViewModel.setLiveActivityEnabled(true)

            #expect(defaults.object(forKey: key) as? Bool == true)
            #expect(app.detailsViewModel.isLiveActivitySwitchOn)
            #expect(app.liveActivity.canRunActivity)
            #expect(isolatedDefaults.object(forKey: key) == nil)
        }
    }

    @Test("REQ-SURF-008 preference changes reconcile the controller through its subscribed stream")
    func preferenceStreamReconcilesController() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = LiveActivityPreferenceStore(userDefaults: defaults)
            let probe = PreferenceReadProbe(store: store)
            let controller = LiveActivityController(
                preference: probe,
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true)
            )
            var reads = probe.reads.stream.makeAsyncIterator()
            #expect(await reads.next() == true)
            await controller.settle()

            store.setEnabled(false)
            #expect(await reads.next() == false)
            await controller.settle()

            store.setEnabled(true)
            #expect(await reads.next() == true)
            await controller.settle()
        }
    }

    @Test("A preference write immediately after controller construction is not lost")
    func immediateWriteIsBufferedBeforeObservationTaskStarts() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let store = LiveActivityPreferenceStore(userDefaults: defaults)
            let probe = PreferenceReadProbe(store: store)
            let controller = LiveActivityController(
                preference: probe, liveActivityPermission: SilentAllowedPermission())

            store.setEnabled(false)

            var reads = probe.reads.stream.makeAsyncIterator()
            #expect(await reads.next() == false)
            await controller.settle()
        }
    }
}

@MainActor
final class PreferenceReadProbe: LiveActivityPreferenceReading {
    private let store: LiveActivityPreferenceStore
    let reads = AsyncStream<Bool>.makeStream()

    init(store: LiveActivityPreferenceStore) { self.store = store }

    var isEnabled: Bool {
        let value = store.isEnabled
        reads.continuation.yield(value)
        return value
    }

    func changes() -> AsyncStream<Void> { store.changes() }
}

private struct SilentAllowedPermission: LiveActivityPermissionSource {
    var areActivitiesEnabled: Bool { true }
    func enablementUpdates() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
}

// UserDefaults owns its synchronization; only the additional counter needs a mutex here.
private final class PreferenceCountingDefaults: UserDefaults, @unchecked Sendable {
    private let writes = Mutex(0)
    var preferenceWrites: Int { writes.withLock { $0 } }

    override func set(_ value: Bool, forKey key: String) {
        if key == "subscription.liveActivity.enabled" { writes.withLock { $0 += 1 } }
        super.set(value, forKey: key)
    }
}
