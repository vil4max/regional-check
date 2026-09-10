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

    private lazy var templateBuilder: CarPlayTemplateBuilder = .init(
        status: status,
        statusDetails: statusDetails,
        regions: regions,
        subscription: subscription,
        location: location,
        onRefresh: { [weak self] in
            guard let self else { return }
            await refreshAndRender()
        },
        onShowDetails: { [weak self] _ in
            self?.pushDetailsTemplate()
        }
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

        let initialTemplate = templateBuilder.rootTemplate(state: status.state, regionTitle: status.regionTitle)
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
        let updated = templateBuilder.rootTemplate(state: status.state, regionTitle: status.regionTitle)
        if let detailsTemplate {
            detailsTemplate.title = updated.title
            detailsTemplate.items = templateBuilder.detailItems()
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

    private func refreshAndRender() async {
        await status.refresh()
        dependencies.syncLiveActivityContent()
        await render(animated: true)
    }

    private func pushDetailsTemplate() {
        guard let interfaceController else { return }
        let template = CPInformationTemplate(
            title: (interfaceController.rootTemplate as? CPInformationTemplate)?.title
                ?? String(localized: "driver.details"),
            layout: .leading, items: templateBuilder.detailItems(), actions: []
        )
        detailsTemplate = template
        interfaceController.pushTemplate(template, animated: false, completion: nil)
    }
}
