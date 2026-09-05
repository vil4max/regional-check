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

struct CarPlayStatusContent: Equatable {
    let title: String
    let regionTitle: String
    let regionDetail: String?
    let detailRows: [String]

    static func make(
        state: StatusState,
        regionTitle: String,
        detailsState: StatusDetailsViewModel.PresentationState
    ) -> CarPlayStatusContent {
        let rows: [String]
        if case let .result(resultRows) = detailsState {
            rows = Array(resultRows.prefix(3))
        } else {
            rows = [state.explanation]
        }
        return CarPlayStatusContent(
            title: state.title,
            regionTitle: regionTitle,
            regionDetail: state.detailText,
            detailRows: rows
        )
    }
}

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    static var dependenciesProvider: (() -> CarPlayDependencies)?

    private var interfaceController: CPInterfaceController?
    private var connectionGate = CarPlayConnectionGate()
    private let dependencies: CarPlayDependencies

    override init() {
        guard let dependenciesProvider = Self.dependenciesProvider else {
            preconditionFailure("CarPlay dependencies must be configured before scene creation")
        }
        dependencies = dependenciesProvider()
        super.init()
    }

    private var location: LocationManager { dependencies.location }
    private var regions: RegionSelection { dependencies.regions }
    private var status: StatusController { dependencies.status }
    private var statusDetails: StatusDetailsViewModel { dependencies.statusDetails }

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
        status.endPeriodicRefresh()
        location.endUpdating()
        dependencies.liveActivity.endCarPlaySession()
    }

    private func armRegionObservation() {
        armObservation { [self] in
            _ = regions.selectedRegion
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

    private func render(animated: Bool) async {
        guard let interfaceController else { return }
        do {
            try await interfaceController.setRootTemplate(
                makeRootTemplate(state: status.state, regionTitle: status.regionTitle),
                animated: animated
            )
        } catch {}
    }

    private var subscription: SubscriptionManager { dependencies.subscription }

    private func makeRootTemplate(state: StatusState, regionTitle: String) -> CPTemplate {
        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: regionTitle,
            detailsState: statusDetails.presentationState
        )
        var items: [CPInformationItem] = [
            CPInformationItem(title: content.regionTitle, detail: content.regionDetail)
        ]
        items.append(contentsOf: content.detailRows.map { CPInformationItem(title: $0, detail: nil) })
        if subscription.allows(.extendedDetail) {
            let source = StatusSourceLabel.displayName(for: status.lastSourceRaw)
            if !source.isEmpty {
                items.append(
                    CPInformationItem(
                        title: "\(NSLocalizedString("status.source.label", comment: "")) \(source)",
                        detail: nil
                    )
                )
            }
        }
        if status.isDataStale {
            items.append(
                CPInformationItem(
                    title: NSLocalizedString("status.stale", comment: ""),
                    detail: nil
                )
            )
        }
        if location.isAuthorizationBlocked {
            items.append(
                CPInformationItem(
                    title: NSLocalizedString("location.access.denied.carplay", comment: ""),
                    detail: nil
                )
            )
        }

        let refresh = CPTextButton(
            title: NSLocalizedString("Refresh", comment: ""),
            textStyle: .confirm
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await status.refresh()
                dependencies.syncLiveActivityContent()
                await render(animated: true)
            }
        }

        return CPInformationTemplate(
            title: content.title,
            layout: .leading,
            items: items,
            actions: [refresh]
        )
    }
}
