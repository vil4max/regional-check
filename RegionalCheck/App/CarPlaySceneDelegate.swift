import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var state: StatusState = .idle
    private var refreshTask: Task<Void, Never>?
    private var regionListenerID: UUID?

    private var location: LocationManager { AppDependencies.location }
    private var regions: RegionSelection { AppDependencies.regions }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController

        regionListenerID = regions.addListener { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAndRender()
            }
        }

        location.onLocationUpdate = { [weak self] coordinate in
            self?.regions.updateFromLocation(coordinate: coordinate)
        }
        location.requestAuthorizationIfNeeded()

        refreshTask?.cancel()
        refreshTask = Task { [weak self, weak interfaceController] in
            guard let self, let interfaceController else { return }

            await self.setRootTemplateSafely(interfaceController, state: .idle, animated: false)
            await self.refreshAndRender()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await self.refreshAndRender()
            }
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        refreshTask?.cancel()
        refreshTask = nil
        location.onLocationUpdate = nil
        if let regionListenerID {
            regions.removeListener(regionListenerID)
            self.regionListenerID = nil
        }
    }

    private func refreshAndRender() async {
        await refreshOnce()
        guard let interfaceController else { return }
        let regionTitle = regions.selectedRegion.title
        await setRootTemplateSafely(interfaceController, state: state, regionTitle: regionTitle, animated: true)
    }

    private func setRootTemplateSafely(
        _ interfaceController: CPInterfaceController,
        state: StatusState,
        regionTitle: String = "Kyiv",
        animated: Bool
    ) async {
        do {
            try await interfaceController.setRootTemplate(
                makeRootTemplate(state: state, regionTitle: regionTitle),
                animated: animated
            )
        } catch {}
    }

    private func makeRootTemplate(state: StatusState, regionTitle: String) -> CPListTemplate {
        let (statusText, detailText) = statusStrings(for: state, regionTitle: regionTitle)

        let statusItem = CPListItem(text: statusText, detailText: detailText)
        statusItem.isEnabled = false

        let refreshItem = CPListItem(text: NSLocalizedString("Refresh", comment: ""), detailText: nil)
        refreshItem.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }
            Task {
                await self.refreshAndRender()
                completion()
            }
        }

        let section = CPListSection(items: [statusItem, refreshItem])
        let template = CPListTemplate(title: regionTitle, sections: [section])
        template.tabTitle = NSLocalizedString("Status", comment: "")
        template.tabImage = UIImage(systemName: "circle.fill")
        return template
    }

    private func statusStrings(for state: StatusState, regionTitle: String) -> (String, String?) {
        switch state {
        case .idle:
            return (String(localized: "Checking…"), regionTitle)
        case .alarm(let lastCheckedAt, _):
            let title = String(localized: "Loud")
            let detail = String(format: String(localized: "Updated: %@"), format(lastCheckedAt))
            return (title, detail)
        case .quiet(let lastCheckedAt, _):
            let title = String(localized: "Quiet")
            let detail = String(format: String(localized: "Updated: %@"), format(lastCheckedAt))
            return (title, detail)
        case .error:
            return (String(localized: "Unknown"), String(localized: "Tap Refresh to try again"))
        }
    }

    private func format(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func refreshOnce() async {
        do {
            let snapshot = try await AppDependencies.provider.fetchStatus(region: regions.selectedRegion)
            switch snapshot.status {
            case .alarm:
                state = .alarm(lastCheckedAt: snapshot.checkedAt, source: snapshot.source)
            case .quiet:
                state = .quiet(lastCheckedAt: snapshot.checkedAt, source: snapshot.source)
            }
        } catch {
            state = .error(message: String(localized: "Unknown"))
        }
    }
}
