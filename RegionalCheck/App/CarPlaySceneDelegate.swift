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

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    static var dependenciesProvider: (() -> CarPlayDependencies)?

    private var interfaceController: CPInterfaceController?
    private var refreshDisplayTask: Task<Void, Never>?
    private weak var detailsTemplate: CPInformationTemplate?
    private var connectionGate = CarPlayConnectionGate()
    private let dependencies: CarPlayDependencies

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

    private var statusDetails: StatusDetailsViewModel {
        dependencies.statusDetails
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
        self.interfaceController = interfaceController
        location.beginUpdating()
        status.setRegion(regions.selectedRegion)

        let initialTemplate = makeRootTemplate(state: status.state, regionTitle: status.regionTitle)
        interfaceController.setRootTemplate(initialTemplate, animated: false) { _, _ in }
        refreshDisplayTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self else { return }
                await render(animated: false)
            }
        }

        armRegionObservation()
        armLocationObservation()
        armStatusObservation()
        armStatusDetailsObservation()
        statusDetails.activate()
        status.beginPeriodicRefresh()
        dependencies.liveActivity.beginCarPlaySession()
        dependencies.syncLiveActivityContent()

        Task { @MainActor [weak self] in
            guard let self, connectionGate.isConnected else { return }
            await status.refresh()
            dependencies.syncLiveActivityContent()
            await render(animated: true)
        }
    }

    private func handleDisconnect() {
        guard connectionGate.disconnect() else { return }
        interfaceController = nil
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
            status.setRegion(regions.selectedRegion)
            await status.refresh()
            dependencies.syncLiveActivityContent()
            await render(animated: true)
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
            statusDetails.synchronizeWithCurrentContext()
            await render(animated: true)
            dependencies.syncLiveActivityContent()
        }
    }

    private func armStatusDetailsObservation() {
        armObservation { [self] in
            _ = statusDetails.presentationState
        } onChange: { [weak self] in
            guard let self else { return }
            await render(animated: true)
        }
    }

    private func armLocationObservation() {
        armObservation { [self] in
            _ = location.coordinateStamp
            _ = location.authorizationStatus
        } onChange: { [weak self] in
            guard let self else { return }
            if let fix = location.lastFix {
                regions.updateFromLocation(fix: fix)
            }
            await render(animated: true)
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

    private func render(animated _: Bool) async {
        guard let interfaceController else { return }
        let updated = makeRootTemplate(state: status.state, regionTitle: status.regionTitle)
        if let detailsTemplate {
            detailsTemplate.title = updated.title
            detailsTemplate.items = detailItems()
        }
        if let current = interfaceController.rootTemplate as? CPInformationTemplate {
            current.title = updated.title
            current.items = updated.items
            current.actions = updated.actions
            return
        }
        do {
            try await interfaceController.setRootTemplate(
                updated,
                animated: false
            )
        } catch {}
    }

    private var subscription: SubscriptionManager {
        dependencies.subscription
    }

    private func makeRootTemplate(state: StatusState, regionTitle: String) -> CPInformationTemplate {
        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: regionTitle,
            detailsState: statusDetails.presentationState
        )
        let mode = regions.followsLocation
            ? (regions.isOutsideUkraine ? String(localized: "driver.region.outside")
                : String(localized: "driver.region.automatic"))
            : String(localized: "driver.region.manual")
        var items = [CPInformationItem(title: content.regionTitle, detail: mode)]
        let historical = state.phase == .error || status.isDataStale
        if historical, let previous = status.lastKnownState {
            items.append(CPInformationItem(
                title: String(localized: "driver.last_status") + " " + previous.title,
                detail: previous.detailText
            ))
        } else if let detail = state.detailText {
            items.append(CPInformationItem(title: detail, detail: nil))
        }
        if location.isAuthorizationBlocked {
            items.append(
                CPInformationItem(
                    title: NSLocalizedString("location.access.denied.carplay", comment: ""),
                    detail: nil
                )
            )
        } else if !historical, state.phase == .quiet, let snapshot = status.lastSnapshot {
            let alerts = snapshot.statuses.compactMap { $0.value == .alarm ? $0.key : nil }
            let nearby = NearbyRegionPolicy.activeAlerts(near: status.currentRegion, among: alerts)
            if !nearby.isEmpty {
                items.append(CPInformationItem(
                    title: String(format: String(localized: "driver.nearby"), nearby.count), detail: nil
                ))
            }
        }

        let refresh = CPTextButton(
            title: status.isLoading ? String(localized: "Checking…") : String(localized: "Refresh"),
            textStyle: .normal
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !status.isLoading else { return }
                await status.refresh()
                dependencies.syncLiveActivityContent()
                await render(animated: true)
            }
        }

        let details = CPTextButton(title: String(localized: "driver.details"), textStyle: .normal) { [weak self] _ in
            guard let self, let interfaceController else { return }
            let template = CPInformationTemplate(
                title: (interfaceController.rootTemplate as? CPInformationTemplate)?.title
                    ?? String(localized: "driver.details"),
                layout: .leading, items: detailItems(), actions: []
            )
            detailsTemplate = template
            interfaceController.pushTemplate(template, animated: false, completion: nil)
        }
        return CPInformationTemplate(
            title: historical ? "? \(String(localized: "driver.no_current_data"))"
                : "\(statusMarker(for: state)) \(content.title)",
            layout: .leading,
            items: items,
            actions: [refresh, details]
        )
    }

    private func statusMarker(for state: StatusState) -> String {
        switch state {
        case .alarm: "🚨"
        case .quiet: "✓"
        case .idle: "↻"
        case .error, .regionUnavailable: "?"
        }
    }

    private func detailItems() -> [CPInformationItem] {
        var rows = [CPInformationItem(title: status.regionTitle, detail: status.state.detailText)]
        if status.isDataStale || status.state.phase == .error {
            rows.append(CPInformationItem(title: String(localized: "driver.no_current_data"), detail: nil))
            if let previous = status.lastKnownState {
                rows.append(CPInformationItem(
                    title: String(localized: "driver.last_status") + " " + previous.title, detail: previous.detailText
                ))
            }
        } else {
            let content = CarPlayStatusContent.make(
                state: status.state, regionTitle: status.regionTitle, detailsState: statusDetails.presentationState
            )
            rows.append(contentsOf: content.detailRows.map { CPInformationItem(title: $0, detail: nil) })
        }
        if subscription.allows(.extendedDetail) {
            rows.append(CPInformationItem(
                title: String(localized: "status.source.label"),
                detail: StatusSourceLabel.displayName(for: status.lastSourceRaw)
            ))
        }
        return rows
    }
}
