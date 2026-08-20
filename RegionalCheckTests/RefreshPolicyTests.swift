import Foundation
@testable import RegionalCheck
import Testing

struct RefreshPolicyTests {
    @Test
    func baselineIsSixtySeconds() {
        let env = RefreshEnvironment(
            isAlarmActive: false,
            isLowPowerModeEnabled: false,
            thermalState: .nominal,
            isExpensiveNetwork: false,
            isConstrainedNetwork: false
        )
        #expect(RefreshPolicy.baseIntervalSeconds(for: env) == 60)
    }

    @Test
    func alarmShortensInterval() {
        let env = RefreshEnvironment(
            isAlarmActive: true,
            isLowPowerModeEnabled: false,
            thermalState: .nominal,
            isExpensiveNetwork: false,
            isConstrainedNetwork: false
        )
        #expect(RefreshPolicy.baseIntervalSeconds(for: env) == 30)
    }

    @Test
    func constrainedContextWinsOverAlarm() {
        let cases: [RefreshEnvironment] = [
            .init(
                isAlarmActive: true,
                isLowPowerModeEnabled: true,
                thermalState: .nominal,
                isExpensiveNetwork: false,
                isConstrainedNetwork: false
            ),
            .init(
                isAlarmActive: true,
                isLowPowerModeEnabled: false,
                thermalState: .serious,
                isExpensiveNetwork: false,
                isConstrainedNetwork: false
            ),
            .init(
                isAlarmActive: true,
                isLowPowerModeEnabled: false,
                thermalState: .nominal,
                isExpensiveNetwork: true,
                isConstrainedNetwork: false
            ),
            .init(
                isAlarmActive: false,
                isLowPowerModeEnabled: false,
                thermalState: .nominal,
                isExpensiveNetwork: false,
                isConstrainedNetwork: true
            )
        ]
        for env in cases {
            #expect(RefreshPolicy.baseIntervalSeconds(for: env) == 300)
        }
    }

    @Test
    func jitterStaysWithinTenPercent() {
        let env = RefreshEnvironment(
            isAlarmActive: false,
            isLowPowerModeEnabled: false,
            thermalState: .nominal,
            isExpensiveNetwork: false,
            isConstrainedNetwork: false
        )
        let low = RefreshPolicy.interval(for: env, jitterUnitInterval: 0)
        let high = RefreshPolicy.interval(for: env, jitterUnitInterval: 1)
        #expect(low == .seconds(54))
        #expect(high == .seconds(66))
    }
}
