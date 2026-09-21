import CarPlay
import Observation
import UIKit

@MainActor
struct CarPlayDependencies {
    let location: any CarPlayLocationSource
    let regions: RegionSelection
    let status: StatusController
    let subscription: SubscriptionManager
    let liveActivity: LiveActivityController
    let statusDetails: StatusDetailsViewModel
    let mapImage: MapViewModel
    let syncLiveActivityContent: () -> Void

    init(container: AppContainer) {
        location = container.location
        regions = container.regions
        status = container.status
        subscription = container.subscription
        liveActivity = container.liveActivity
        statusDetails = container.statusDetailsViewModel
        mapImage = container.carPlayMapImage
        syncLiveActivityContent = container.syncLiveActivityContent
    }
}

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPTabBarTemplateDelegate {
    static var dependenciesProvider: (() -> CarPlayDependencies)?

    private var interfaceController: CPInterfaceController?
    private var refreshDisplayTask: Task<Void, Never>?
    private weak var statusTemplate: CPInformationTemplate?
    private weak var mapTemplate: CPListTemplate?
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
        subscription: subscription,
        onRefresh: { [weak self] in
            self?.awaitingManualRefreshResult = true
            self?.coordinator.refresh(reason: "manual")
        }
    )

    private lazy var mapBuilder: CarPlayMapBuilder = .init(
        status: status,
        onRefresh: { [weak self] in
            self?.mapImage.refresh()
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

    private var subscription: SubscriptionManager {
        dependencies.subscription
    }

    private var mapImage: MapViewModel {
        dependencies.mapImage
    }

    private func mapImageState() -> CarPlayMapImageState {
        CarPlayMapImageState(
            imageData: mapImage.imageData,
            loadedAt: mapImage.loadedAt,
            loadFailed: mapImage.loadFailed
        )
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        handleConnect(interfaceController, contentStyle: templateApplicationScene.contentStyle)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to _: CPWindow
    ) {
        handleConnect(interfaceController, contentStyle: templateApplicationScene.contentStyle)
    }

    /// CarPlay can be dark while the phone is light (or the reverse): the raster's day/night
    /// variant follows the car's own trait collection, never the phone's `colorScheme`.
    func templateApplicationScene(
        _: CPTemplateApplicationScene,
        contentStyleDidChange contentStyle: UIUserInterfaceStyle
    ) {
        applyContentStyle(contentStyle)
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

    /// Builds the two tabs, Status and Map, and stores them on `statusTemplate`/`mapTemplate`,
    /// without touching `interfaceController` — building `CPTemplate` values needs no live
    /// CarPlay connection, unlike `CPInterfaceController`, which has no public initializer and so
    /// cannot be constructed from a test. Splitting this out of `handleConnect` is what makes the
    /// Map tab's tab-select-triggered load provable at all (`CarPlayConnectionTests
    /// .mapTabAppear_loadsOnlyOnSelection`); do not fold it back into `handleConnect`.
    /// Not `private` for that same reason.
    func makeRootTemplates(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> CPTabBarTemplate {
        let statusInfo = templateBuilder.rootTemplate(loadState: loadState, freshness: freshness)
        statusInfo.tabTitle = String(localized: "driver.status.tab_title")
        statusInfo.tabImage = UIImage(systemName: "steeringwheel")
        // Image load is on tab appear / Refresh map only (REQ-REFRESH-001, REQ-PROVIDER-002):
        // never fetched here, only once `tabBarTemplate(_:didSelect:)` picks this tab.
        let map = mapBuilder.mapTemplate(loadState: loadState, freshness: freshness, image: mapImageState())
        statusTemplate = statusInfo
        mapTemplate = map
        let tabs = CPTabBarTemplate(templates: [statusInfo, map])
        tabs.delegate = self
        return tabs
    }

    private func handleConnect(_ interfaceController: CPInterfaceController, contentStyle: UIUserInterfaceStyle) {
        guard connectionGate.connect() else { return }
        CarPlayLog.lifecycle.info("CarPlay didConnect")
        self.interfaceController = interfaceController
        location.beginUpdating()
        status.setRegion(regions.selectedRegion)
        applyContentStyle(contentStyle)
        // Starts before the first template so the cached snapshot is shown as `loading`
        // right away, independent of whether the phone scene ever becomes active.
        coordinator.refresh(reason: "connect")

        let loadState = coordinator.loadState
        let freshness = coordinator.freshness()
        let tabs = makeRootTemplates(loadState: loadState, freshness: freshness)
        interfaceController.setRootTemplate(tabs, animated: false) { installed, error in
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
        armMapImageObservation()
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
        mapTemplate = nil
        refreshDisplayTask?.cancel()
        refreshDisplayTask = nil
        status.endPeriodicRefresh()
        location.endUpdating()
        mapImage.disappear()
        dependencies.liveActivity.endCarPlaySession()
    }

    /// `rednight` is deliberately not offered (a red tint reads as an alarm color); day/night is
    /// the only choice, driven by the car's own trait collection, never the phone's `colorScheme`.
    private func applyContentStyle(_ contentStyle: UIUserInterfaceStyle) {
        mapImage.setVariant(contentStyle == .light ? .day : .night)
    }

    /// CPTabBarTemplateDelegate: the Map tab loads its image on appear only (never at connect,
    /// never on a timer) — REQ-REFRESH-001 "fetch only for an active surface".
    func tabBarTemplate(_: CPTabBarTemplate, didSelect selectedTemplate: CPTemplate) {
        guard selectedTemplate === mapTemplate else { return }
        mapImage.appear()
    }

    /// Not `private`: `CarPlayConnectionTests` calls this directly to prove the 15 s reactive
    /// loop only re-renders the Map tab's existing rows (`mapBuilder.sections`) and never starts
    /// a new image fetch — the negative half of REQ-REFRESH-001, which an audit alone can't prove
    /// stays true as this file changes.
    func render(reason: CarPlayRenderReason) async {
        guard let statusTemplate, let mapTemplate else {
            // The templates are held weakly. If one is gone, every later render is dropped and the
            // tabs freeze on their last content while the head unit's tab strip still responds —
            // the shape of the owner's in-car screenshots. Say so instead of returning silently.
            CarPlayLog.lifecycle.error("Render dropped: a CarPlay template was deallocated")
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
        mapTemplate.updateSections(mapBuilder.sections(
            loadState: loadState,
            freshness: freshness,
            image: mapImageState()
        ))
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
/// `mapImage`/`location` never lapses after the first change. Kept in the same file as
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

    private func armMapImageObservation() {
        armObservation { [self] in
            _ = mapImage.imageData
            _ = mapImage.loadedAt
            _ = mapImage.loadFailed
        } onChange: { [weak self] in
            guard let self, let mapTemplate else { return }
            mapTemplate.updateSections(
                mapBuilder.sections(
                    loadState: coordinator.loadState,
                    freshness: coordinator.freshness(),
                    image: mapImageState()
                )
            )
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
