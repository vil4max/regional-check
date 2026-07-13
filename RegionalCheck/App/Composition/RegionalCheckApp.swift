import SwiftUI

@main
struct RegionalCheckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: coordinator)
        }
    }
}
