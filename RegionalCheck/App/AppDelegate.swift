import AppIntents
import CarPlay
import DriveCheckKit
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Built on first use rather than in `init`: as the unit-test host the app never
    /// touches it, so tests run without live network, StoreKit, or location wiring.
    private(set) lazy var container: AppContainer = {
        #if DEBUG
            if let phase = AppLaunchArguments.screenshotPhase,
               ["allClear", "alertActive", "unavailable"].contains(phase)
            {
                let network = FixtureNetwork()
                network.failsRequests = phase == "unavailable"
                return AppContainer.fixture(
                    region: phase == "alertActive" ? .kharkiv : .kyivCity,
                    network: network,
                    hasCachedSnapshot: phase != "unavailable",
                    defaultsSuite: "vil4max.RegionalCheck.screenshot.\(phase)"
                )
            }
        #endif
        return AppContainer()
    }()

    override init() {
        super.init()

        CarPlaySceneDelegate.dependenciesProvider = { [self] in
            CarPlayDependencies(container: container)
        }
        // Registered at launch because iOS may launch the app only to perform the Live
        // Activity's Refresh intent, with no scene; resolving it is what builds the container.
        AppDependencyManager.shared.add { @MainActor [self] () async -> any LiveActivityRefreshing in
            LiveActivityRefresher(status: container.status, liveActivity: container.liveActivity)
        }
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        CarPlayLog.lifecycle.info("didFinishLaunching")
        return true
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication
            || connectingSceneSession.configuration.name == "CarPlay"
        {
            let config = UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
            config.delegateClass = CarPlaySceneDelegate.self
            config.sceneClass = CPTemplateApplicationScene.self
            return config
        }

        return UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
    }
}
