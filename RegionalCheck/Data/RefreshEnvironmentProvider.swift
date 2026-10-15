import DriveCheckKit
import Foundation

/// `RefreshPolicy` and `DataFreshness` live in DriveCheckKit. This alias keeps the name visible to
/// app files that do not import the Kit (`CarPlayLoadState.swift`); delete it once they do.
typealias DataFreshness = DriveCheckKit.DataFreshness

@MainActor
protocol RefreshEnvironmentProviding: AnyObject {
    func current(isAlarmActive: Bool) -> RefreshEnvironment
}

@MainActor
final class SystemRefreshEnvironmentProvider: RefreshEnvironmentProviding {
    private let pathMonitor: any NetworkPathMonitoring

    init(pathMonitor: (any NetworkPathMonitoring)? = nil) {
        let monitor = pathMonitor ?? LiveNetworkPathMonitor()
        self.pathMonitor = monitor
        monitor.start()
    }

    func current(isAlarmActive: Bool) -> RefreshEnvironment {
        let process = ProcessInfo.processInfo
        let path = pathMonitor.currentPath
        return RefreshEnvironment(
            isAlarmActive: isAlarmActive,
            isLowPowerModeEnabled: process.isLowPowerModeEnabled,
            thermalState: process.thermalState,
            isExpensiveNetwork: path.isExpensive,
            isConstrainedNetwork: path.isConstrained
        )
    }
}
