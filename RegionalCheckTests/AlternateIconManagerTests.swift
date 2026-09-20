import DriveCheckKit
import Foundation
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

/// ADR 0014: while Pro is hidden the icon is pinned to the primary one. `AlternateIconManager`
/// keeps its REQ-SURF-004 contract above; what changes is that nothing feeds it an entitlement.
@MainActor
struct ProHiddenIconPinTests {
    @Test("REQ-SURF-007 a session start reverts an already applied Pro icon, even for a subscriber")
    func sessionStartPinsThePrimaryIcon() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let presenter = RecordingIconPresenter(alternateIconName: AlternateIconManager.proIconName)
            let manager = makeManager(
                entitlement: .active(TestFixtures.activeEntitlement),
                presenter: presenter,
                defaults: defaults
            )

            await manager.start()

            #expect(manager.isPro)
            #expect(presenter.appliedNames == [nil])
        }
    }

    @Test("REQ-SURF-007 gaining an entitlement never applies the Pro icon")
    func entitlementGrantLeavesTheIconAlone() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let presenter = RecordingIconPresenter()
            let manager = makeManager(entitlement: .none, presenter: presenter, defaults: defaults)
            await manager.start()

            _ = await manager.restore()

            #expect(manager.isPro)
            #expect(presenter.appliedNames.isEmpty)
        }
    }

    private func makeManager(
        entitlement: EntitlementVerification,
        presenter: RecordingIconPresenter,
        defaults: UserDefaults
    ) -> SubscriptionManager {
        SubscriptionManager(
            service: FakeSubscriptionService(
                products: [],
                entitlement: entitlement,
                restoreEntitlement: .active(TestFixtures.activeEntitlement)
            ),
            cache: EntitlementCache(userDefaults: defaults),
            userDefaults: defaults,
            entitlementPersistence: SharedStore(userDefaults: defaults),
            widgetReloader: TestWidgetReloader(),
            iconPresenter: presenter
        )
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
