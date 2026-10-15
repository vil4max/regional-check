import Foundation
@testable import RegionalCheck
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProAppearanceTests {
    @Test("REQ-SURF-007 PRO-COSMETIC AC-3 an owner gets the Pro icon by default and can switch it off and on")
    func ownerSwitchesTheIcon() {
        TestDefaults.withTemporaryDefaults { defaults in
            let presenter = RecordingIconPresenter()
            let appearance = ProAppearance(
                ownership: FakeOwnership(isPro: true),
                defaults: defaults,
                iconPresenter: presenter
            )

            appearance.start()
            appearance.setUsesProIcon(false)
            appearance.setUsesProIcon(true)

            #expect(
                presenter.appliedNames == [AlternateIconManager.proIconName, nil, AlternateIconManager.proIconName])
        }
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-3 the icon choice persists across launches")
    func iconChoicePersists() {
        TestDefaults.withTemporaryDefaults { defaults in
            let presenter = RecordingIconPresenter()
            let first = ProAppearance(
                ownership: FakeOwnership(isPro: true), defaults: defaults, iconPresenter: presenter)
            first.setUsesProIcon(false)

            let next = ProAppearance(
                ownership: FakeOwnership(isPro: true), defaults: defaults, iconPresenter: presenter)

            #expect(next.usesProIcon == false)
        }
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-2 an owner known from the cache is decorated before any change event")
    func ownerIsKnownBeforeAnyEvent() {
        TestDefaults.withTemporaryDefaults { defaults in
            let appearance = ProAppearance(
                ownership: FakeOwnership(isPro: true),
                defaults: defaults,
                iconPresenter: RecordingIconPresenter()
            )

            #expect(appearance.isOwner)
            #expect(Theme.RedesignPalette.current(isProEntitled: appearance.isOwner) == .pro)
        }
    }

    @Test("REQ-SURF-007 PRO-COSMETIC AC-2 buying Pro turns on the decoration and the Pro icon")
    func gainingProDecoratesAndAppliesTheIcon() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let ownership = FakeOwnership(isPro: false)
            let presenter = RecordingIconPresenter()
            let appearance = ProAppearance(ownership: ownership, defaults: defaults, iconPresenter: presenter)
            appearance.start()

            ownership.isPro = true
            await ownership.sendChange()

            #expect(appearance.isOwner)
            #expect(presenter.appliedNames == [AlternateIconManager.proIconName])
        }
    }

    @Test("REQ-SURF-004 PRO-COSMETIC AC-4 losing Pro restores the primary icon even with the switch on")
    func losingProRestoresThePrimaryIcon() async {
        await TestDefaults.withTemporaryDefaults { defaults in
            let ownership = FakeOwnership(isPro: true)
            let presenter = RecordingIconPresenter()
            let appearance = ProAppearance(ownership: ownership, defaults: defaults, iconPresenter: presenter)
            appearance.start()

            ownership.isPro = false
            await ownership.sendChange()

            #expect(appearance.isOwner == false)
            #expect(presenter.appliedNames == [AlternateIconManager.proIconName, nil])
        }
    }

    @Test("REQ-SURF-007 PRO-COSMETIC a driver without Pro never gets the Pro icon")
    func nonOwnerKeepsThePrimaryIcon() {
        TestDefaults.withTemporaryDefaults { defaults in
            let presenter = RecordingIconPresenter()
            let appearance = ProAppearance(
                ownership: FakeOwnership(isPro: false),
                defaults: defaults,
                iconPresenter: presenter
            )

            appearance.start()
            appearance.setUsesProIcon(true)

            #expect(presenter.appliedNames.isEmpty)
        }
    }
}

@MainActor
private final class FakeOwnership: ProOwnershipSource {
    var isPro: Bool
    private var continuations: [AsyncStream<Void>.Continuation] = []

    init(isPro: Bool) {
        self.isPro = isPro
    }

    func entitlementChanges() -> AsyncStream<Void> {
        AsyncStream { continuations.append($0) }
    }

    /// Yields one change and returns once the observer has had the chance to apply it.
    func sendChange() async {
        continuations.forEach { $0.yield() }
        for _ in 0..<20 {
            await Task.yield()
        }
    }
}
