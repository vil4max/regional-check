import Foundation

/// What the polling interval depends on (REQ-REFRESH-002). The app reads it from the system; the
/// extensions cannot see Low Power Mode or the network path and pass the unconstrained values.
public struct RefreshEnvironment: Equatable, Sendable {
    public var isAlarmActive: Bool
    public var isLowPowerModeEnabled: Bool
    public var thermalState: ProcessInfo.ThermalState
    public var isExpensiveNetwork: Bool
    public var isConstrainedNetwork: Bool

    public init(
        isAlarmActive: Bool,
        isLowPowerModeEnabled: Bool,
        thermalState: ProcessInfo.ThermalState,
        isExpensiveNetwork: Bool,
        isConstrainedNetwork: Bool
    ) {
        self.isAlarmActive = isAlarmActive
        self.isLowPowerModeEnabled = isLowPowerModeEnabled
        self.thermalState = thermalState
        self.isExpensiveNetwork = isExpensiveNetwork
        self.isConstrainedNetwork = isConstrainedNetwork
    }

    public var isConstrainedContext: Bool {
        isLowPowerModeEnabled
            || thermalState == .serious
            || thermalState == .critical
            || isConstrainedNetwork
    }
}

/// The polling intervals (REQ-REFRESH-002) and the fetch floor (REQ-REFRESH-010), the one copy
/// every target reads.
public enum RefreshPolicy {
    public static let baselineSeconds: TimeInterval = 60
    public static let alarmSeconds: TimeInterval = 30
    public static let constrainedSeconds: TimeInterval = 300
    public static let jitterFraction: Double = 0.10

    /// Minimum spacing between network fetches (REQ-REFRESH-010). Above the provider's 3 s server
    /// cache, inside which a refetch returns identical data, and below the 27 s a scheduled alarm
    /// poll can reach after jitter, so the floor never swallows a scheduled poll.
    public static let fetchFloorSeconds: TimeInterval = 10

    public static func baseIntervalSeconds(for environment: RefreshEnvironment) -> TimeInterval {
        if environment.isConstrainedContext {
            return constrainedSeconds
        }
        if environment.isAlarmActive {
            return alarmSeconds
        }
        return baselineSeconds
    }

    public static func interval(
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
