import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct FoldGlassSettingsTests {
    @Test("REQ-FG-001 the fold glass is on until the driver turns it off, and the choice is kept")
    func settingDefaultsOnAndPersists() {
        TestDefaults.withTemporaryDefaults { defaults in
            let settings = FoldGlassSettings(userDefaults: defaults)
            #expect(settings.isEnabled)

            settings.isEnabled = false
            #expect(!FoldGlassSettings(userDefaults: defaults).isEnabled)

            settings.isEnabled = true
            #expect(FoldGlassSettings(userDefaults: defaults).isEnabled)
        }
    }

    @Test("REQ-FG-001 the Details switch reads and writes the fold glass setting")
    func detailsSwitchDrivesTheSetting() {
        TestDefaults.withTemporaryDefaults { defaults in
            let settings = FoldGlassSettings(userDefaults: defaults)
            let container = AppContainer.fixture(
                defaultsSuite: "RegionalCheckTests.foldGlass.\(UUID().uuidString)",
                foldGlassSettings: settings
            )
            #expect(container.detailsViewModel.isFoldGlassEnabled)

            container.detailsViewModel.setFoldGlassEnabled(false)
            #expect(!settings.isEnabled)
            #expect(!container.detailsViewModel.isFoldGlassEnabled)
        }
    }

    @Test("REQ-FG-002 Reduce Motion always turns the fold glass off")
    func reduceMotionTurnsItOff() {
        #expect(!FoldGlassGate.isActive(
            isEnabled: true,
            reduceMotion: true,
            isSuspended: false,
            isSceneActive: true,
            isLowPowerMode: false
        ))
        #expect(FoldGlassGate.isActive(
            isEnabled: true,
            reduceMotion: false,
            isSuspended: false,
            isSceneActive: true,
            isLowPowerMode: false
        ))
    }

    @Test("REQ-FG-001 REQ-FG-002 the setting, the cold start and the background also keep Home flat")
    func otherGatesKeepItFlat() {
        #expect(!FoldGlassGate.isActive(
            isEnabled: false,
            reduceMotion: false,
            isSuspended: false,
            isSceneActive: true,
            isLowPowerMode: false
        ))
        #expect(!FoldGlassGate.isActive(
            isEnabled: true,
            reduceMotion: false,
            isSuspended: true,
            isSceneActive: true,
            isLowPowerMode: false
        ))
        #expect(!FoldGlassGate.isActive(
            isEnabled: true,
            reduceMotion: false,
            isSuspended: false,
            isSceneActive: false,
            isLowPowerMode: false
        ))
    }

    @Test("REQ-FG-003 Low Power Mode keeps Home flat")
    func lowPowerModeKeepsItFlat() {
        #expect(!FoldGlassGate.isActive(
            isEnabled: true,
            reduceMotion: false,
            isSuspended: false,
            isSceneActive: true,
            isLowPowerMode: true
        ))
    }
}
