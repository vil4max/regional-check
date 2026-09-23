import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct DetailsViewModelTests {
    @Test("REQ-REGION-009 Details reports blocked location access so it can offer Open Settings")
    func locationAccessFollowsTheLocationSource() {
        let location = FakeDetailsLocationSource()
        let sut = makeSUT(location: location)
        #expect(sut.isLocationAccessBlocked == false)

        location.isAuthorizationBlocked = true
        #expect(sut.isLocationAccessBlocked)
    }

    @Test("REQ-SURF-007 the Live Activity switch on Details is the user's own and needs no entitlement")
    func liveActivitySwitchIsForwardedWithoutAnEntitlement() {
        TestDefaults.withTemporaryDefaults { defaults in
            let subscription = SubscriptionManager(
                service: FakeSubscriptionService(products: [], entitlement: .none),
                cache: EntitlementCache(userDefaults: defaults),
                userDefaults: defaults,
                entitlementPersistence: SharedStore(userDefaults: defaults),
                widgetReloader: TestWidgetReloader()
            )
            var forwarded: [Bool] = []
            let sut = DetailsViewModel(
                location: FakeDetailsLocationSource(),
                subscription: subscription,
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
                foldGlass: isolatedFoldGlassSettings(),
                setLiveActivityEnabled: { enabled in
                    forwarded.append(enabled)
                    subscription.setLiveActivityEnabled(enabled)
                }
            )

            sut.setLiveActivityEnabled(false)
            #expect(sut.isLiveActivityEnabled == false)
            sut.setLiveActivityEnabled(true)
            #expect(sut.isLiveActivityEnabled)
            #expect(forwarded == [false, true])
            #expect(subscription.isPro == false)
        }
    }

    @Test
    func versionLineCarriesTheVersionAndTheBuild() {
        let text = DetailsViewModel.versionBuildText(version: "3.0.0", build: "4")
        #expect(text.contains("3.0.0"))
        #expect(text.contains("4"))
    }

    private func makeSUT(location: FakeDetailsLocationSource) -> DetailsViewModel {
        DetailsViewModel(
            location: location,
            subscription: AppContainer.fixture().subscription,
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
            foldGlass: isolatedFoldGlassSettings(),
            setLiveActivityEnabled: { _ in }
        )
    }
}

@MainActor
struct LiveActivitySwitchTests {
    @Test("REQ-SURF-008 with Live Activities off in iOS Settings the switch reads off and keeps the driver's choice")
    func systemOffOverridesTheShownStateNotTheChoice() {
        let subscription = AppContainer.fixture().subscription
        subscription.setLiveActivityEnabled(true)
        let sut = DetailsViewModel(
            location: FixedLocation(),
            subscription: subscription,
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: false),
            foldGlass: isolatedFoldGlassSettings(),
            setLiveActivityEnabled: { _ in }
        )

        #expect(sut.isLiveActivityAllowedBySystem == false)
        #expect(sut.isLiveActivitySwitchOn == false)
        #expect(sut.isLiveActivityEnabled)
    }

    @Test("REQ-SURF-008 with Live Activities allowed the switch shows the driver's own choice")
    func systemOnShowsTheChoice() {
        let subscription = AppContainer.fixture().subscription
        let sut = DetailsViewModel(
            location: FixedLocation(),
            subscription: subscription,
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
            foldGlass: isolatedFoldGlassSettings(),
            setLiveActivityEnabled: { subscription.setLiveActivityEnabled($0) }
        )

        sut.setLiveActivityEnabled(false)
        #expect(sut.isLiveActivitySwitchOn == false)
        sut.setLiveActivityEnabled(true)
        #expect(sut.isLiveActivitySwitchOn)
    }

    @Test("REQ-SURF-008 turning Live Activities off in Settings while Details is open is picked up")
    func settingsChangeIsFollowed() async {
        let permission = SwitchablePermission(initial: true)
        let sut = DetailsViewModel(
            location: FixedLocation(),
            subscription: AppContainer.fixture().subscription,
            liveActivityPermission: permission,
            foldGlass: isolatedFoldGlassSettings(),
            setLiveActivityEnabled: { _ in }
        )
        #expect(sut.isLiveActivityAllowedBySystem)

        let observation = Task { await sut.observeLiveActivityPermission() }
        permission.change(to: false)
        for _ in 0 ..< 100 where sut.isLiveActivityAllowedBySystem {
            await Task.yield()
        }
        #expect(sut.isLiveActivityAllowedBySystem == false)
        observation.cancel()
    }
}

@MainActor
private final class FixedLocation: HomeLocationSource {
    var isAuthorizationBlocked = false
}

private final class SwitchablePermission: LiveActivityPermissionSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Bool
    private var continuation: AsyncStream<Bool>.Continuation?

    init(initial: Bool) {
        current = initial
    }

    var areActivitiesEnabled: Bool {
        lock.withLock { current }
    }

    func enablementUpdates() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        lock.withLock { self.continuation = continuation }
        return stream
    }

    /// Yields only once a subscriber exists, like the real sequence, so the test waits for it.
    func change(to value: Bool) {
        Task {
            for _ in 0 ..< 100 where lock.withLock({ continuation == nil }) {
                await Task.yield()
            }
            lock.withLock {
                current = value
                continuation?.yield(value)
            }
        }
    }
}

@MainActor
private final class FakeDetailsLocationSource: HomeLocationSource {
    var isAuthorizationBlocked = false
}

/// These tests never touch the fold glass switch; an isolated suite keeps them hermetic.
@MainActor
private func isolatedFoldGlassSettings() -> FoldGlassSettings {
    FoldGlassSettings(userDefaults: UserDefaults(suiteName: "RegionalCheckTests.details.\(UUID().uuidString)") ??
        .standard)
}
