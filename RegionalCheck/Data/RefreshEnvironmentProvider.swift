import DriveCheckKit
import Foundation

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
