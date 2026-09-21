import CarPlay
import Observation
import UIKit

@MainActor
struct CarPlayDependencies {
    let location: any CarPlayLocationSource
    let regions: RegionSelection
    let status: StatusController
    let liveActivity: LiveActivityController
    let statusDetails: StatusDetailsViewModel
    let syncLiveActivityContent: () -> Void

    init(container: AppContainer) {
        location = container.location
        regions = container.regions
        status = container.status
        liveActivity = container.liveActivity
        statusDetails = container.statusDetailsViewModel
        syncLiveActivityContent = container.syncLiveActivityContent
    }
}

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    static var dependenciesProvider: (() -> CarPlayDependencies)?

    private var interfaceController: CPInterfaceController?
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

    private var regions: RegionSelection {
        dependencies.regions
    }

    private var status: StatusController {
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

    private func handleConnect(_ interfaceController: CPInterfaceController) {
        guard connectionGate.connect() else { return }
        CarPlayLog.lifecycle.info("CarPlay didConnect")
        self.interfaceController = interfaceController
        location.beginUpdating()
        status.setRegion(regions.selectedRegion)
        // Starts before the first template so the cached snapshot is shown as `loading`
        // right away, independent of whether the phone scene ever becomes active.
        coordinator.refresh(reason: "connect")

        let loadState = coordinator.loadState
        let freshness = coordinator.freshness()
        let root = makeRootTemplate(loadState: loadState, freshness: freshness)
        interfaceController.setRootTemplate(root, animated: false) { installed, error in
            // A failed install means no render ever reaches the screen again, and it used to say
            // nothing at all.
            if !installed || error != nil {
                let reason = error.map { String(describing: $0) } ?? "not installed"
                CarPlayLog.lifecycle.error("Root template install failed: \(reason, privacy: .public)")
            }
        }
        renderCoalescer.seed(renderSnapshot(loadState: loadState, freshness: freshness))
        if let statusTemplate {
            logTemplateUpdate(statusTemplate)
        }
        refreshDisplayTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self else { return }
                await render(reason: .reactive)
            }
        }

        armRegionObservation()
        armLocationObservation()
        armStatusObservation()
        armLoadStateObservation()
        status.beginPeriodicRefresh()
        dependencies.liveActivity.beginCarPlaySession()
        dependencies.syncLiveActivityContent()
    }

    private func handleDisconnect() {
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
            phase: freshSnapshot?.state.phase
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
            status.setRegion(regions.selectedRegion)
            await status.refresh()
            dependencies.syncLiveActivityContent()
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
