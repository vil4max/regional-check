import CarPlay
import UIKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let container: AppContainer

    override init() {
        container = AppContainer()
        super.init()

        configureTabBarAppearance()

        CarPlaySceneDelegate.dependenciesProvider = { [container] in
            CarPlayDependencies(container: container)
        }
    }

    private func configureTabBarAppearance() {
        let tabBar = UITabBar.appearance()
        tabBar.tintColor = UIColor.white
        tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.62)
    }

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication
            || connectingSceneSession.configuration.name == "CarPlay" {
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
