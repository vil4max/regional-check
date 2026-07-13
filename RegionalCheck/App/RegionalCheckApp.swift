import SwiftUI

@main
struct RegionalCheckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

enum AppDependencies {
    static let provider = UbillingProvider()

    @MainActor
    static let location = LocationManager()

    @MainActor
    static let regions = RegionSelection()
}
