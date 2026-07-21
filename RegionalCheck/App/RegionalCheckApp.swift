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

@MainActor
enum AppDependencies {
    static let provider = UbillingProvider()
    static let location = LocationManager()
    static let regions = RegionSelection()
    static let status = StatusController(region: regions.selectedRegion, provider: provider)
}
