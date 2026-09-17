import CarPlay
import Observation
import UIKit

@MainActor
struct CarPlayDependencies {
    let location: LocationManager
    let regions: RegionSelection
    let status: StatusController
    let subscription: SubscriptionManager
    let liveActivity: LiveActivityController
    let statusDetails: StatusDetailsViewModel
    let syncLiveActivityContent: () -> Void

    init(container: AppContainer) {
        location = container.location
        regions = container.regions
        status = container.status
        subscription = container.subscription
        liveActivity = container.liveActivity
        statusDetails = container.statusDetailsViewModel
        syncLiveActivityContent = container.syncLiveActivityContent
    }
}

@MainActor
struct CarPlayStatusContent: Equatable {
    let title: String
    let regionTitle: String
    let regionDetail: String?
    let detailRows: [String]
    let usesStatusDetails: Bool

    static func make(
        state: StatusState,
        regionTitle: String,
        detailsState: StatusDetailsViewModel.PresentationState
    ) -> CarPlayStatusContent {
        let rows: [String]
        let usesStatusDetails: Bool
        if case let .result(resultRows) = detailsState {
            rows = Array(resultRows.prefix(3))
            usesStatusDetails = true
        } else {
            rows = [state.explanation]
            usesStatusDetails = false
        }
        return CarPlayStatusContent(
            title: state.title,
            regionTitle: regionTitle,
            regionDetail: state.detailText,
            detailRows: rows,
            usesStatusDetails: usesStatusDetails
        )
    }
}

/// What the driver currently sees, reduced to just what deciding "should this update
/// interrupt the 10 s coalescing window" needs (REQ-REFRESH data-row cadence). Two renders
/// with an equal snapshot are a no-op; a snapshot whose `isFresh`/`phase` differs from the
/// last *applied* one is a transition the driver must see immediately (fresh ↔ stale,
/// quiet ↔ alarm), regardless of how recently the last update landed.
struct CarPlayRenderSnapshot: Equatable {
    let loadState: CarPlayLoadState
    let isFresh: Bool
    let phase: StatusState.Phase?
}

enum CarPlayRenderReason: Equatable {
    case reactive
    case manualRefreshResult
}

/// Coalesces CarPlay data-row updates to at most one every 10 s (driving-task guidance:
/// don't refresh data rows more often than every 10 s), except a manual-refresh result or a
/// must-see transition, which always applies immediately. Pure and clock-injectable so it is
/// testable without any CarPlay API.
@MainActor
final class CarPlayRenderCoalescer {
    static let minInterval: Duration = .seconds(10)

    private let now: () -> Date
    private var lastApplied: CarPlayRenderSnapshot?
    private var lastAppliedAt: Date?

    init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    /// Records the initially-displayed snapshot so the first reactive update afterward is
    /// measured against the real connect time, not treated as an unconditional first render.
    func seed(_ snapshot: CarPlayRenderSnapshot) {
        lastApplied = snapshot
        lastAppliedAt = now()
    }

    /// Returns whether the caller should push the rebuilt templates to CarPlay. Marks the
    /// snapshot as applied when it returns `true`.
    func shouldApply(_ snapshot: CarPlayRenderSnapshot, reason: CarPlayRenderReason) -> Bool {
        guard snapshot != lastApplied else { return false }
        let mustSeeNow = reason == .manualRefreshResult || isMustSeeTransition(from: lastApplied, to: snapshot)
        let intervalElapsed = lastAppliedAt.map { now().timeIntervalSince($0) >= Self.minInterval.timeInterval } ?? true
        guard mustSeeNow || intervalElapsed else { return false }
        lastApplied = snapshot
        lastAppliedAt = now()
        return true
    }

    private func isMustSeeTransition(from old: CarPlayRenderSnapshot?, to new: CarPlayRenderSnapshot) -> Bool {
        guard let old else { return true }
        return old.isFresh != new.isFresh || old.phase != new.phase
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    static var dependenciesProvider: (() -> CarPlayDependencies)?

    private var interfaceController: CPInterfaceController?
    private var refreshDisplayTask: Task<Void, Never>?
    private weak var statusTemplate: CPInformationTemplate?
    private weak var detailsTemplate: CPListTemplate?
    private var connectionGate = CarPlayConnectionGate()
    private var hasLoggedFirstLocation = false
    private var awaitingManualRefreshResult = false
    private let dependencies: CarPlayDependencies
    private let renderCoalescer = CarPlayRenderCoalescer()

    private lazy var coordinator: CarPlayRefreshCoordinator = .init(
        status: status,
        location: location,
        regions: regions
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

    private lazy var detailsBuilder: CarPlayDetailsBuilder = .init(
        status: status,
        regions: regions,
        subscription: subscription
    )

    override init() {
        guard let dependenciesProvider = Self.dependenciesProvider else {
            preconditionFailure("CarPlay dependencies must be configured before scene creation")
        }
        dependencies = dependenciesProvider()
        super.init()
    }

    private var location: LocationManager {
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
        let statusInfo = templateBuilder.rootTemplate(loadState: loadState, freshness: freshness)
        statusInfo.tabTitle = String(localized: "driver.status.tab_title")
        statusInfo.tabImage = UIImage(systemName: "steeringwheel")
        let details = detailsBuilder.detailsTemplate(loadState: loadState, freshness: freshness)
        statusTemplate = statusInfo
        detailsTemplate = details
        let tabs = CPTabBarTemplate(templates: [statusInfo, details])
        interfaceController.setRootTemplate(tabs, animated: false) { _, _ in }
        renderCoalescer.seed(renderSnapshot(loadState: loadState, freshness: freshness))
        logTemplateUpdate(statusInfo)
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
        detailsTemplate = nil
        refreshDisplayTask?.cancel()
        refreshDisplayTask = nil
        status.endPeriodicRefresh()
        location.endUpdating()
        dependencies.liveActivity.endCarPlaySession()
    }

    private func armRegionObservation() {
        armObservation { [self] in
            _ = regions.selectedRegion
            _ = regions.followsLocation
            _ = regions.isOutsideUkraine
        } onChange: { [weak self] in
            guard let self else { return }
            CarPlayLog.lifecycle.info("Region determined: follows=\(regions.followsLocation, privacy: .public)")
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

    private func render(reason: CarPlayRenderReason) async {
        guard let statusTemplate, let detailsTemplate else { return }
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
        detailsTemplate.updateSections(detailsBuilder.sections(loadState: loadState, freshness: freshness))
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
