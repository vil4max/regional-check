import CarPlay
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

// Serialized: the CarPlay dependencies provider is one global, saved and restored per test.
@Suite(.serialized, .removesDefaultsSuites, .restoresCarPlayDependencies)
struct CarPlayConnectionTests {
    @Test
    func connect_isIdempotent() {
        var gate = CarPlayConnectionGate()
        let first = gate.connect()
        #expect(first)
        #expect(gate.isConnected)
        let second = gate.connect()
        #expect(second == false)
        #expect(gate.isConnected)
    }

    @Test
    func disconnect_isIdempotent() {
        var gate = CarPlayConnectionGate()
        let firstDisconnect = gate.disconnect()
        #expect(firstDisconnect == false)
        let connected = gate.connect()
        #expect(connected)
        let disconnected = gate.disconnect()
        #expect(disconnected)
        #expect(gate.isConnected == false)
        let secondDisconnect = gate.disconnect()
        #expect(secondDisconnect == false)
    }

    @Test
    @MainActor
    func appDelegate_bootstrapsCarPlayDependenciesBeforeSceneConfiguration() {
        CarPlaySceneDelegate.dependenciesProvider = nil

        _ = AppDelegate()

        #expect(CarPlaySceneDelegate.dependenciesProvider != nil)
    }

    @Test("REQ-REFRESH-002 phone and CarPlay share one ref-counted timer")
    @MainActor
    func periodicRefresh_survivesDuplicateCarPlayConnectDisconnect() {
        let controller = StatusController(
            region: .kyivCity,
            provider: MockStatusProvider(snapshot: TestFixtures.quietSnapshot())
        )
        #expect(controller.isPeriodicRefreshRunning == false)

        controller.beginPeriodicRefresh()
        controller.beginPeriodicRefresh()
        #expect(controller.isPeriodicRefreshRunning)

        // The bug the ref count exists to prevent: CarPlay disconnecting while the phone shell is
        // still open must not stop the timer the phone is using.
        controller.endPeriodicRefresh()
        #expect(controller.isPeriodicRefreshRunning)

        controller.endPeriodicRefresh()
        #expect(controller.isPeriodicRefreshRunning == false)
    }

    // MARK: - Root template
    // `CPInterfaceController` has no public initializer, so these build the root template through
    // `makeRootTemplate(loadState:freshness:)` and `render(reason:)`; the session lifecycle tests
    // drive `handleConnect` through a stand-in installer.

    @MainActor
    private func makeDelegate() -> (delegate: CarPlaySceneDelegate, app: AppContainer) {
        let app = AppContainer.fixture(defaultsSuite: TestDefaults.fixtureSuite("carplay-connection"))
        CarPlaySceneDelegate.dependenciesProvider = { CarPlayDependencies(container: app) }
        return (CarPlaySceneDelegate(), app)
    }

    @MainActor
    private func freshness(_ app: AppContainer) -> CarPlayFreshness {
        CarPlayFreshness(
            now: AppContainer.fixtureNow,
            refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: app.status.refreshEnvironment())
        )
    }

    @Test("REQ-SURF-006 CarPlay's root is one Status screen, no tab bar, built without an entitlement")
    @MainActor
    func rootTemplateIsTheStatusScreen() {
        let (delegate, app) = makeDelegate()

        let root = delegate.makeRootTemplate(loadState: .loading(cached: nil), freshness: freshness(app))

        #expect(app.subscription.isPro == false)
        #expect(root.actions.count == 1)
    }
}

extension CarPlayConnectionTests {

    @Test("REQ-SURF-006 a reactive render updates the one screen and requests no map image")
    @MainActor
    func reactiveRenderRequestsNoMapImage() async {
        let network = FixtureNetwork()
        let app = AppContainer.fixture(
            network: network,
            defaultsSuite: TestDefaults.fixtureSuite("carplay-connection")
        )
        CarPlaySceneDelegate.dependenciesProvider = { CarPlayDependencies(container: app) }
        let delegate = CarPlaySceneDelegate()
        _ = delegate.makeRootTemplate(loadState: .loading(cached: nil), freshness: freshness(app))

        await delegate.render(reason: .reactive)

        #expect(network.mapRequestCount == 0)
    }

    // MARK: - CarPlayRenderCoalescer
    // Data rows update no more than every 10 s, except a manual-refresh result or a must-see change.

    private func snapshot(
        state: StatusState = .quiet(lastCheckedAt: .now),
        isFresh: Bool = true,
        regionTitle: String = "Kyiv Oblast"
    ) -> CarPlayRenderSnapshot {
        let checkedAt = state.checkedAt ?? .now
        let cp = CarPlaySnapshot(state: state, regionTitle: regionTitle, checkedAt: checkedAt)
        return CarPlayRenderSnapshot(loadState: .loaded(cp), isFresh: isFresh, phase: isFresh ? state.phase : nil)
    }

    @Test
    @MainActor
    func coalescer_preservesTheWindowForARegionTitleOnlyChange() {
        var now = Date(timeIntervalSince1970: 0)
        let state = StatusState.quiet(lastCheckedAt: now)
        let coalescer = CarPlayRenderCoalescer(now: { now })
        coalescer.seed(snapshot(state: state))
        let changed = snapshot(state: state, regionTitle: "Kharkiv Oblast")
        now += 1

        #expect(!coalescer.shouldApply(changed, reason: .reactive))
        now += 9
        #expect(coalescer.shouldApply(changed, reason: .reactive))
        #expect(!coalescer.shouldApply(changed, reason: .reactive))
    }

    @Test
    @MainActor
    func coalescer_appliesTheFirstSnapshotEvenWithoutSeeding() {
        let coalescer = CarPlayRenderCoalescer(now: { .now })

        #expect(coalescer.shouldApply(snapshot(), reason: .reactive))
    }

    @Test
    @MainActor
    func coalescer_skipsAnUnchangedSnapshot() {
        let coalescer = CarPlayRenderCoalescer(now: { .now })
        let value = snapshot()
        coalescer.seed(value)

        #expect(coalescer.shouldApply(value, reason: .reactive) == false)
    }

    @Test
    @MainActor
    func coalescer_skipsAChangedSnapshotWithinTenSecondsUnlessItMustBeSeen() {
        var now = Date(timeIntervalSince1970: 0)
        let coalescer = CarPlayRenderCoalescer(now: { now })
        coalescer.seed(snapshot(state: .quiet(lastCheckedAt: now)))
        now += 3
        // Same phase and freshness, only the checkedAt in the snapshot moved: not a must-see change.
        let stillQuiet = snapshot(state: .quiet(lastCheckedAt: now))

        #expect(coalescer.shouldApply(stillQuiet, reason: .reactive) == false)

        now += 8  // 11 s total: past the 10 s window
        #expect(coalescer.shouldApply(snapshot(state: .quiet(lastCheckedAt: now)), reason: .reactive))
    }

    @Test
    @MainActor
    func coalescer_appliesAManualRefreshResultImmediately() {
        var now = Date(timeIntervalSince1970: 0)
        let coalescer = CarPlayRenderCoalescer(now: { now })
        coalescer.seed(snapshot(state: .quiet(lastCheckedAt: now)))
        now += 2

        #expect(coalescer.shouldApply(snapshot(state: .quiet(lastCheckedAt: now)), reason: .manualRefreshResult))
    }

    @Test
    @MainActor
    func coalescer_appliesAFreshToStaleTransitionImmediately() {
        var now = Date(timeIntervalSince1970: 0)
        let coalescer = CarPlayRenderCoalescer(now: { now })
        coalescer.seed(snapshot(isFresh: true))
        now += 2

        #expect(coalescer.shouldApply(snapshot(isFresh: false), reason: .reactive))
    }

    @Test
    @MainActor
    func coalescer_appliesAQuietToAlarmTransitionImmediately() {
        var now = Date(timeIntervalSince1970: 0)
        let coalescer = CarPlayRenderCoalescer(now: { now })
        coalescer.seed(snapshot(state: .quiet(lastCheckedAt: now)))
        now += 2

        #expect(coalescer.shouldApply(snapshot(state: .alarm(lastCheckedAt: now)), reason: .reactive))
    }
}

extension CarPlayConnectionTests {
    @Test(arguments: [(true, false), (false, true)])
    @MainActor
    func coalescer_appliesALocationRowChangeImmediately(_ blocked: Bool, _ outside: Bool) {
        var now = Date(timeIntervalSince1970: 0)
        let state = StatusState.quiet(lastCheckedAt: now)
        let coalescer = CarPlayRenderCoalescer(now: { now })
        coalescer.seed(snapshot(state: state))
        var changed = snapshot(state: state)
        changed.isLocationBlocked = blocked
        changed.isOutsideUkraine = outside
        now += 1

        #expect(coalescer.shouldApply(changed, reason: .reactive))
    }
}

// MARK: - Session lifecycle

extension CarPlayConnectionTests {
    @Test("REQ-REFRESH-002 one connect and disconnect begin and end each CarPlay session client exactly once")
    @MainActor
    func connectAndDisconnectBalanceTheSessionClients() async throws {
        let harness = CarPlaySessionHarness()

        harness.delegate.handleConnect(harness.installer)
        harness.delegate.handleConnect(harness.installer)

        #expect(harness.installer.installed.count == 1)
        let root = try #require(harness.installer.installed.first as? CPInformationTemplate)
        #expect(root.actions.map(\.title) == ["Checking…"])
        #expect(harness.location.beginCount == 1)
        #expect(harness.status.periodicRefreshBegins == 1)
        #expect(harness.liveActivity.carPlayBegins == 1)
        try #require(await eventually { harness.status.refreshCount == 1 })
        try #require(await eventually { harness.displaySleep.durations.count == 1 })
        #expect(harness.displaySleep.durations == [CarPlaySceneDelegate.displayRefreshInterval])

        harness.delegate.handleDisconnect()
        harness.delegate.handleDisconnect()

        #expect(harness.location.endCount == 1)
        #expect(harness.status.periodicRefreshEnds == 1)
        #expect(harness.liveActivity.carPlayEnds == 1)
        try #require(await eventually { harness.displaySleep.cancellations == 1 })
        #expect(harness.location.beginCount == 1)
        #expect(harness.status.periodicRefreshBegins == 1)
        #expect(harness.liveActivity.carPlayBegins == 1)
    }

    @Test("REQ-REGION-009 a location-blocked change inside the 10 s window reaches the CarPlay screen")
    @MainActor
    func locationBlockedChangeInsideTheCoalescingWindowIsApplied() async throws {
        let denied = String(localized: "location.access.denied.carplay")
        let harness = CarPlaySessionHarness()
        harness.delegate.handleConnect(harness.installer)
        let root = try #require(harness.installer.installed.first as? CPInformationTemplate)
        #expect(!root.items.contains { $0.title == denied })

        harness.location.authorizationStatus = .denied
        await harness.delegate.render(reason: .reactive)

        #expect(root.items.contains { $0.title == denied })
        harness.delegate.handleDisconnect()
    }
}

/// A scene delegate over fakes: counting session clients, a stand-in root installer and a display
/// sleep that records each pause and its cancellation.
@MainActor
private final class CarPlaySessionHarness {
    let status = FakeCarPlayStatus(region: .kyivCity, snapshot: FixtureNetwork.snapshot(alarmRegions: []))
    let regions = FakeCarPlayRegions()
    let location = FakeCarPlayLocation()
    let liveActivity = CarPlayLiveActivitySpy()
    let installer = RootTemplateInstallerSpy()
    let displaySleep = DisplaySleepRecorder()
    let delegate: CarPlaySceneDelegate

    init() {
        let dependencies = CarPlayDependencies(
            location: location,
            regions: regions,
            status: status,
            liveActivity: liveActivity,
            syncLiveActivityContent: {},
            displaySleep: { [displaySleep] in try await displaySleep.sleep($0) }
        )
        CarPlaySceneDelegate.dependenciesProvider = { dependencies }
        delegate = CarPlaySceneDelegate()
    }
}

@MainActor
private final class DisplaySleepRecorder {
    private(set) var durations: [Duration] = []
    private(set) var cancellations = 0

    /// Suspends until cancelled, so the display loop never renders on its own during a test.
    func sleep(_ duration: Duration) async throws {
        durations.append(duration)
        do {
            try await Task.sleep(for: .seconds(3600))
        } catch {
            cancellations += 1
            throw error
        }
    }
}

/// AppDelegate.init and these tests re-point CarPlaySceneDelegate's static dependencies provider.
/// Restoring it after each test keeps a later scene delegate from building whichever graph a
/// test left behind, including AppDelegate's live container.
private struct RestoresCarPlayDependenciesTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for _: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        guard testCase != nil else { return try await function() }
        let saved = await SavedCarPlayDependencies()
        do {
            try await function()
        } catch {
            await saved.restore()
            throw error
        }
        await saved.restore()
    }
}

@MainActor
private final class SavedCarPlayDependencies {
    private let provider = CarPlaySceneDelegate.dependenciesProvider

    func restore() {
        CarPlaySceneDelegate.dependenciesProvider = provider
    }
}

extension Trait where Self == RestoresCarPlayDependenciesTrait {
    fileprivate static var restoresCarPlayDependencies: Self { Self() }
}
