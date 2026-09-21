import CarPlay
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

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

    @Test
    @MainActor
    func carPlayPrimaryStatusRemainsDeterministicWhileDetailsAreLoading() {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let state = StatusState.alarm(lastCheckedAt: checkedAt)

        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: "Kyiv City",
            detailsState: .loading
        )

        #expect(content.title == state.title)
        #expect(content.regionTitle == "Kyiv City")
        #expect(content.regionDetail == state.detailText)
        #expect(content.detailRows == [state.explanation])
        #expect(content.usesStatusDetails == false)
    }

    @Test
    @MainActor
    func carPlayAIEnhancementChangesOnlySupplementaryRows() {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let state = StatusState.quiet(lastCheckedAt: checkedAt)

        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: "Kyiv City",
            detailsState: .result(["Generated country context", "Generated nearby context"])
        )

        #expect(content.title == state.title)
        #expect(content.regionTitle == "Kyiv City")
        #expect(content.regionDetail == state.detailText)
        #expect(content.detailRows == ["Generated country context", "Generated nearby context"])
        #expect(content.usesStatusDetails)
    }

    @Test
    @MainActor
    func carPlayLimitsGeneratedRowsToThree() {
        let state = StatusState.quiet(lastCheckedAt: Date(timeIntervalSince1970: 1_700_000_000))

        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: "Kyiv City",
            detailsState: .result(["1", "2", "3", "4"])
        )

        #expect(content.detailRows == ["1", "2", "3"])
        #expect(content.usesStatusDetails)
    }

    // MARK: - Root template (REQ-SURF-006)

    //
    // `CPInterfaceController` has no public initializer, so `templateApplicationScene(_:didConnect:)`
    // cannot be driven from a test — only `CPTemplate` subtypes are constructible standalone.
    // `makeRootTemplate(loadState:freshness:)` and `render(reason:)` are the two pieces of
    // `CarPlaySceneDelegate` this reaches without one.

    @MainActor
    private func makeDelegate() -> (delegate: CarPlaySceneDelegate, app: AppContainer) {
        let app = AppContainer.fixture(defaultsSuite: "RegionalCheckTests.carplay-connection.\(UUID().uuidString)")
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

    @Test("REQ-SURF-006 a reactive render updates the one screen and requests no map image")
    @MainActor
    func reactiveRenderRequestsNoMapImage() async {
        let network = FixtureNetwork()
        let app = AppContainer.fixture(
            network: network,
            defaultsSuite: "RegionalCheckTests.carplay-connection.\(UUID().uuidString)"
        )
        CarPlaySceneDelegate.dependenciesProvider = { CarPlayDependencies(container: app) }
        let delegate = CarPlaySceneDelegate()
        _ = delegate.makeRootTemplate(loadState: .loading(cached: nil), freshness: freshness(app))

        await delegate.render(reason: .reactive)

        #expect(network.mapRequestCount == 0)
    }

    // MARK: - CarPlayRenderCoalescer (RD-8b: data rows update no more than every 10 s)

    private func snapshot(
        state: StatusState = .quiet(lastCheckedAt: .now),
        isFresh: Bool = true
    ) -> CarPlayRenderSnapshot {
        let checkedAt = state.checkedAt ?? .now
        let cp = CarPlaySnapshot(state: state, regionTitle: "Kyiv Oblast", checkedAt: checkedAt)
        return CarPlayRenderSnapshot(loadState: .loaded(cp), isFresh: isFresh, phase: isFresh ? state.phase : nil)
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

        now += 8 // 11 s total: past the 10 s window
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
