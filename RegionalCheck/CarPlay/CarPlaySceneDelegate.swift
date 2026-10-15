import CarPlay
import DriveCheckKit
import Observation
import UIKit

/// What a CarPlay session reads from, observes on and asks of the status store.
@MainActor
protocol CarPlaySessionStatus: CarPlayStatusRefreshing {
    var state: StatusState { get }
    var statusDetailsRevision: Int? { get }
    func beginPeriodicRefresh()
    func endPeriodicRefresh()
}

/// The region owner as a CarPlay session uses it: read for the screen, fed with location fixes.
@MainActor
protocol CarPlayRegionFollowing: CarPlayRegionReading {
    func updateFromLocation(fix: LocationFix)
}

/// Installs the root template. `CPInterfaceController` has no public initializer, so a test
/// stands in for it here.
@MainActor
protocol CarPlayRootTemplateInstalling: AnyObject {
    func installRootTemplate(_ rootTemplate: CPTemplate)
}

extension StatusController: CarPlaySessionStatus {}
extension RegionSelection: CarPlayRegionFollowing {}

extension CPInterfaceController: CarPlayRootTemplateInstalling {
    func installRootTemplate(_ rootTemplate: CPTemplate) {
        setRootTemplate(rootTemplate, animated: false) { installed, error in
            // A failed install means no later render reaches the screen; say so.
            if !installed || error != nil {
                let reason = error.map { String(describing: $0) } ?? "not installed"
                CarPlayLog.lifecycle.error("Root template install failed: \(reason, privacy: .public)")
            }
        }
    }
}

@MainActor
struct CarPlayDependencies {
    let location: any CarPlayLocationSource
    let regions: any CarPlayRegionFollowing
    let status: any CarPlaySessionStatus
    let liveActivity: any LiveActivityControlling
    let syncLiveActivityContent: () -> Void
    /// The pause between two reactive renders of the display loop.
    let displaySleep: (Duration) async throws -> Void

    init(
        location: any CarPlayLocationSource,
        regions: any CarPlayRegionFollowing,
        status: any CarPlaySessionStatus,
        liveActivity: any LiveActivityControlling,
        syncLiveActivityContent: @escaping () -> Void,
        displaySleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.location = location
        self.regions = regions
        self.status = status
        self.liveActivity = liveActivity
        self.syncLiveActivityContent = syncLiveActivityContent
        self.displaySleep = displaySleep
    }

    init(container: AppContainer) {
        self.init(
            location: container.location,
            regions: container.regions,
            status: container.status,
            liveActivity: container.liveActivity,
            syncLiveActivityContent: container.syncLiveActivityContent
        )
    }
}

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    static var dependenciesProvider: (() -> CarPlayDependencies)?
    static let displayRefreshInterval: Duration = .seconds(15)

    private var interfaceController: (any CarPlayRootTemplateInstalling)?
    private var refreshDisplayTask: Task<Void, Never>?
    private weak var statusTemplate: CPInformationTemplate?
    private var connectionGate = CarPlayConnectionGate()
    private var hasLoggedFirstLocation = false
    private var awaitingManualRefreshResult = false
    private let dependencies: CarPlayDependencies
    private let renderCoalescer = CarPlayRenderCoalescer()

    private lazy var coordinator: CarPlayRefreshCoordinator = .init(
        status: status,
        location: location
    )

    private lazy var templateBuilder: CarPlayTemplateBuilder = .init(
        status: status,
        regions: regions,
        location: location,
        onRefresh: { [weak self] in
            self?.awaitingManualRefreshResult = true
            self?.coordinator.refresh(reason: "manual")
        }
    )

    override init() {
        guard let dependenciesProvider = Self.dependenciesProvider else {
            preconditionFailure("CarPlay dependencies must be configured before scene creation")
        }
        dependencies = dependenciesProvider()
        super.init()
    }

    private var location: any CarPlayLocationSource {
        dependencies.location
    }

    private var regions: any CarPlayRegionFollowing {
        dependencies.regions
    }

    private var status: any CarPlaySessionStatus {
        dependencies.status
    }

    func templateApplicationScene(
        _: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        handleConnect(interfaceController)
    }

    func templateApplicationScene(
        _: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to _: CPWindow
    ) {
        handleConnect(interfaceController)
    }

    func templateApplicationScene(
        _: CPTemplateApplicationScene,
        didDisconnectInterfaceController _: CPInterfaceController
    ) {
        handleDisconnect()
    }

    func templateApplicationScene(
        _: CPTemplateApplicationScene,
        didDisconnect _: CPInterfaceController,
        from _: CPWindow
    ) {
        handleDisconnect()
    }

    /// Builds the one CarPlay screen (REQ-SURF-006) and keeps it on `statusTemplate`, without
    /// touching `interfaceController`: building a `CPTemplate` needs no live CarPlay connection,
    /// unlike `CPInterfaceController`, which has no public initializer and so cannot be
    /// constructed from a test. Not `private` for that reason (`CarPlayConnectionTests`).
    func makeRootTemplate(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> CPInformationTemplate {
        let statusInfo = templateBuilder.rootTemplate(loadState: loadState, freshness: freshness)
        statusTemplate = statusInfo
        return statusInfo
    }

    /// Not `private`: `CarPlayConnectionTests` drives it with a stand-in installer.
    func handleConnect(_ interfaceController: any CarPlayRootTemplateInstalling) {
        guard connectionGate.connect() else { return }
        CarPlayLog.lifecycle.info("CarPlay didConnect")
        self.interfaceController = interfaceController
        location.beginUpdating()
        // Starts before the first template so the cached snapshot is shown as `loading`
        // right away, independent of whether the phone scene ever becomes active.
        coordinator.refresh(reason: "connect")

        let loadState = coordinator.loadState
        let freshness = coordinator.freshness()
        let root = makeRootTemplate(loadState: loadState, freshness: freshness)
        interfaceController.installRootTemplate(root)
        renderCoalescer.seed(renderSnapshot(loadState: loadState, freshness: freshness))
        logTemplateUpdate(root)
        startDisplayLoop()

        armRegionObservation()
        armLocationObservation()
        armStatusObservation()
        armLoadStateObservation()
        status.beginPeriodicRefresh()
        dependencies.liveActivity.beginCarPlaySession()
        dependencies.syncLiveActivityContent()
    }

    /// Not `private`: `CarPlayConnectionTests` drives it.
    func handleDisconnect() {
        guard connectionGate.disconnect() else { return }
        CarPlayLog.lifecycle.info("CarPlay didDisconnect")
        coordinator.cancel()
        interfaceController = nil
        statusTemplate = nil
        refreshDisplayTask?.cancel()
        refreshDisplayTask = nil
        status.endPeriodicRefresh()
        location.endUpdating()
        dependencies.liveActivity.endCarPlaySession()
    }

    /// Re-renders on a fixed beat, so freshness that lapses with no status change still reaches
    /// the screen. Cancelled on disconnect.
    private func startDisplayLoop() {
        let sleep = dependencies.displaySleep
        refreshDisplayTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await sleep(Self.displayRefreshInterval) } catch { return }
                guard let self else { return }
                await render(reason: .reactive)
            }
        }
    }

    /// Not `private`: `CarPlayConnectionTests` drives it directly.
    func render(reason: CarPlayRenderReason) async {
        guard let statusTemplate else {
            // The template is held weakly. If it is gone, every later render is dropped and the
            // screen freezes on its last content. Say so instead of returning silently.
            CarPlayLog.lifecycle.error("Render dropped: the CarPlay template was deallocated")
            return
        }
        let loadState = coordinator.loadState
        let freshness = coordinator.freshness()
        guard renderCoalescer.shouldApply(renderSnapshot(loadState: loadState, freshness: freshness), reason: reason)
        else {
            return
        }
        let updated = templateBuilder.rootTemplate(loadState: loadState, freshness: freshness)
        statusTemplate.title = updated.title
        statusTemplate.items = updated.items
        statusTemplate.actions = updated.actions
        logTemplateUpdate(statusTemplate)
    }

    private func renderSnapshot(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> CarPlayRenderSnapshot {
        let freshSnapshot = loadState.snapshot.flatMap { freshness.isFresh($0) ? $0 : nil }
        return CarPlayRenderSnapshot(
            loadState: loadState,
            isFresh: freshSnapshot != nil,
            phase: freshSnapshot?.state.phase,
            isLocationBlocked: location.isAuthorizationBlocked,
            isOutsideUkraine: regions.isOutsideUkraine
        )
    }

    private func logTemplateUpdate(_ template: CPInformationTemplate) {
        let state = coordinator.loadState.logDescription
        CarPlayLog.lifecycle.info(
            "Template updated: state=\(state, privacy: .public) title=\(template.title, privacy: .public)"
        )
    }
}

/// Reactive wiring: each `arm*Observation` re-registers itself on every fire, so the
/// `withObservationTracking` callback that watches `regions`/`status`/`coordinator`/
/// `location` never lapses after the first change. Kept in the same file as
/// `CarPlaySceneDelegate` (not a separate type) because it reads and calls back into the
/// delegate's own `private` state directly — an extension in another file would need that
/// state widened to `internal`, trading a line-count fix for a real encapsulation loss.
extension CarPlaySceneDelegate {
    private func armRegionObservation() {
        armObservation { [self] in
            _ = regions.selectedRegion
            _ = regions.isOutsideUkraine
        } onChange: { [weak self] in
            guard let self else { return }
            CarPlayLog.lifecycle.info("Region determined")
            await render(reason: .reactive)
        }
    }

    private func armStatusObservation() {
        armObservation { [self] in
            _ = status.state
            _ = status.isLoading
            _ = status.hasRefreshFailed
            _ = status.regionTitle
            _ = status.statusDetailsRevision
            _ = regions.isOutsideUkraine
        } onChange: { [weak self] in
            guard let self else { return }
            coordinator.synchronizeWithStatus()
            await render(reason: .reactive)
            dependencies.syncLiveActivityContent()
        }
    }

    private func armLoadStateObservation() {
        armObservation { [self] in
            _ = coordinator.loadState
        } onChange: { [weak self] in
            guard let self else { return }
            let reason: CarPlayRenderReason = awaitingManualRefreshResult ? .manualRefreshResult : .reactive
            await render(reason: reason)
            // A manual cycle renders both its `loading` flip and its result immediately;
            // it only "ends" once the coordinator leaves `loading`.
            if !coordinator.loadState.isLoading {
                awaitingManualRefreshResult = false
            }
        }
    }

    private func armLocationObservation() {
        armObservation { [self] in
            _ = location.coordinateStamp
            _ = location.authorizationStatus
        } onChange: { [weak self] in
            guard let self else { return }
            if let fix = location.lastFix {
                if !hasLoggedFirstLocation {
                    hasLoggedFirstLocation = true
                    CarPlayLog.lifecycle.info("First location received")
                }
                regions.updateFromLocation(fix: fix)
            }
            await render(reason: .reactive)
        }
    }

    private func armObservation(
        track: @escaping @MainActor () -> Void,
        onChange: @escaping @MainActor () async -> Void
    ) {
        guard connectionGate.isConnected else { return }
        withObservationTracking {
            track()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, connectionGate.isConnected else { return }
                armObservation(track: track, onChange: onChange)
                await onChange()
            }
        }
    }
}
