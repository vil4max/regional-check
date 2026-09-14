import Foundation

struct RefreshEnvironment: Equatable, Sendable {
    var isAlarmActive: Bool
    var isLowPowerModeEnabled: Bool
    var thermalState: ProcessInfo.ThermalState
    var isExpensiveNetwork: Bool
    var isConstrainedNetwork: Bool

    var isConstrainedContext: Bool {
        isLowPowerModeEnabled
            || thermalState == .serious
            || thermalState == .critical
            || isConstrainedNetwork
    }
}

enum RefreshPolicy {
    static let baselineSeconds: TimeInterval = 60
    static let alarmSeconds: TimeInterval = 30
    static let constrainedSeconds: TimeInterval = 300
    static let jitterFraction: Double = 0.10

    static func baseIntervalSeconds(for environment: RefreshEnvironment) -> TimeInterval {
        if environment.isConstrainedContext {
            return constrainedSeconds
        }
        if environment.isAlarmActive {
            return alarmSeconds
        }
        return baselineSeconds
    }

    static func interval(
        for environment: RefreshEnvironment,
        jitterUnitInterval: Double
    ) -> Duration {
        let clamped = min(max(jitterUnitInterval, 0), 1)
        let signed = (clamped * 2) - 1
        let base = baseIntervalSeconds(for: environment)
        let jittered = base * (1 + signed * jitterFraction)
        return .seconds(jittered)
    }
}

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
