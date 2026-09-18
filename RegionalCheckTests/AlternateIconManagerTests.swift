@testable import RegionalCheck
import Testing

@MainActor
struct AlternateIconManagerTests {
    @Test("REQ-SURF-004 losing Pro reverts the app icon to the primary icon")
    func proLossRevertsToPrimaryIcon() {
        let presenter = RecordingIconPresenter(alternateIconName: AlternateIconManager.proIconName)

        AlternateIconManager.sync(isPro: false, presenter: presenter)

        #expect(presenter.appliedNames == [nil])
        #expect(presenter.alternateIconName == nil)
    }

    @Test("REQ-SURF-004 gaining Pro applies the Pro icon")
    func proGrantAppliesProIcon() {
        let presenter = RecordingIconPresenter()

        AlternateIconManager.sync(isPro: true, presenter: presenter)

        #expect(presenter.appliedNames == [AlternateIconManager.proIconName])
    }

    @Test("REQ-SURF-004 an icon that already matches the entitlement is not reapplied")
    func unchangedEntitlementAppliesNothing() {
        let presenter = RecordingIconPresenter(alternateIconName: AlternateIconManager.proIconName)

        AlternateIconManager.sync(isPro: true, presenter: presenter)

        #expect(presenter.appliedNames.isEmpty)
    }

    @Test("REQ-SURF-004 nothing is attempted when the device cannot change the icon")
    func unsupportedDeviceAppliesNothing() {
        let presenter = RecordingIconPresenter(
            supportsAlternateIcons: false,
            alternateIconName: AlternateIconManager.proIconName
        )

        AlternateIconManager.sync(isPro: false, presenter: presenter)

        #expect(presenter.appliedNames.isEmpty)
    }
}

@MainActor
private final class RecordingIconPresenter: AlternateIconPresenting {
    let supportsAlternateIcons: Bool
    private(set) var alternateIconName: String?
    private(set) var appliedNames: [String?] = []

    init(supportsAlternateIcons: Bool = true, alternateIconName: String? = nil) {
        self.supportsAlternateIcons = supportsAlternateIcons
        self.alternateIconName = alternateIconName
    }

    func applyAlternateIconName(_ name: String?) {
        appliedNames.append(name)
        alternateIconName = name
    }
}
