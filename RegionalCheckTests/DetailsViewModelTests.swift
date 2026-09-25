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

    /// The Details snapshots render this line, so it must not follow the host app's
    /// `CFBundleVersion`: every build bump would otherwise change four baselines.
    @Test
    func fixtureVersionLineIsFixedRatherThanReadFromTheBundle() {
        let sut = AppContainer.fixture().detailsViewModel
        #expect(sut.versionBuildText == DetailsViewModel.versionBuildText(version: "3.1.0", build: "1"))
    }

    private func makeSUT(location: FakeDetailsLocationSource) -> DetailsViewModel {
        DetailsViewModel(
            location: location,
            subscription: AppContainer.fixture().subscription,
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
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
            setLiveActivityEnabled: { _ in }
        )
        #expect(sut.isLiveActivityAllowedBySystem)

        let observation = Task { await sut.observeLiveActivityPermission() }
        permission.change(to: false)
        let followed = await eventually(within: .seconds(5)) { sut.isLiveActivityAllowedBySystem == false }
        #expect(followed)
        observation.cancel()
    }

    /// The Settings-change test above depends on this: on a loaded runner the view model can
    /// subscribe long after `change(to:)` is called, and the change must still reach it.
    @Test
    func switchablePermissionHoldsAChangeForALateSubscriber() async throws {
        let permission = SwitchablePermission(initial: true)
        permission.change(to: false)
        // Later than any fixed number of scheduler turns the fake could wait for.
        try await Task.sleep(for: .milliseconds(100))

        let delivered = await firstValue(of: permission.enablementUpdates(), within: .seconds(2))
        #expect(delivered == false)
    }
}

/// The first element `stream` yields, or `nil` when none arrives within `timeout`.
private func firstValue<Element: Sendable>(
    of stream: AsyncStream<Element>,
    within timeout: Duration
) async -> Element? {
    await withTaskGroup(of: Element?.self) { group in
        group.addTask { await stream.first { _ in true } }
        group.addTask {
            try? await Task.sleep(for: timeout)
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}

/// Whether `condition` holds before `timeout` elapses. Bounded by the clock rather than by a
/// count of `Task.yield()` calls, which a loaded runner can use up before the update arrives.
@MainActor
private func eventually(within timeout: Duration, _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}

@MainActor
private final class FixedLocation: HomeLocationSource {
    var isAuthorizationBlocked = false
}

private final class SwitchablePermission: LiveActivityPermissionSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Bool
    private var continuation: AsyncStream<Bool>.Continuation?
    private var subscriberWaiters: [CheckedContinuation<Void, Never>] = []

    init(initial: Bool) {
        current = initial
    }

    var areActivitiesEnabled: Bool {
        lock.withLock { current }
    }

    func enablementUpdates() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let waiters = lock.withLock {
            self.continuation = continuation
            defer { subscriberWaiters = [] }
            return subscriberWaiters
        }
        for waiter in waiters {
            waiter.resume()
        }
        return stream
    }

    /// Yields only once a subscriber exists, like the real sequence, however late it subscribes.
    func change(to value: Bool) {
        Task {
            await subscribed()
            lock.withLock {
                current = value
                continuation?.yield(value)
            }
        }
    }

    /// Returns once `enablementUpdates()` has been called, signalled by it rather than polled.
    private func subscribed() async {
        await withCheckedContinuation { waiter in
            let isSubscribed = lock.withLock {
                if continuation != nil {
                    return true
                }
                subscriberWaiters.append(waiter)
                return false
            }
            if isSubscribed {
                waiter.resume()
            }
        }
    }
}

@MainActor
private final class FakeDetailsLocationSource: HomeLocationSource {
    var isAuthorizationBlocked = false
}
