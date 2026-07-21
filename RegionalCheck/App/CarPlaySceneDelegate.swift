import CarPlay
import Observation
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var refreshTask: Task<Void, Never>?
    private var isConnected = false

    private var location: LocationManager { AppDependencies.location }
    private var regions: RegionSelection { AppDependencies.regions }
    private var status: StatusController { AppDependencies.status }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        isConnected = true
        location.beginUpdating()
        status.setRegion(regions.selectedRegion)
        armRegionObservation()
        armLocationObservation()

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }

            await self.render(animated: false)
            await self.status.refresh()
            await self.render(animated: true)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await self.status.refresh()
                await self.render(animated: true)
            }
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        isConnected = false
        self.interfaceController = nil
        refreshTask?.cancel()
        refreshTask = nil
        location.endUpdating()
    }

    private func armRegionObservation() {
        guard isConnected else { return }
        withObservationTracking {
            _ = regions.selectedRegion
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isConnected else { return }
                self.status.setRegion(self.regions.selectedRegion)
                await self.status.refresh()
                await self.render(animated: true)
                self.armRegionObservation()
            }
        }
    }

    private func armLocationObservation() {
        guard isConnected else { return }
        withObservationTracking {
            _ = location.coordinateStamp
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isConnected else { return }
                if let coordinate = self.location.coordinate {
                    self.regions.updateFromLocation(coordinate: coordinate)
                }
                self.armLocationObservation()
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

    private func makeRootTemplate(state: StatusState, regionTitle: String) -> CPListTemplate {
        let statusItem = CPListItem(text: state.title, detailText: state.detailText)
        statusItem.isEnabled = false
        statusItem.setImage(UIImage(systemName: state.symbolName))

        let refreshItem = CPListItem(text: NSLocalizedString("Refresh", comment: ""), detailText: nil)
        refreshItem.setImage(UIImage(systemName: "arrow.clockwise"))
        refreshItem.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }
            Task {
                await self.status.refresh()
                await self.render(animated: true)
                completion()
            }
        }

        let section = CPListSection(items: [statusItem, refreshItem])
        let template = CPListTemplate(title: regionTitle, sections: [section])
        template.tabTitle = NSLocalizedString("Status", comment: "")
        template.tabImage = UIImage(systemName: state.symbolName)
        return template
    }
}
