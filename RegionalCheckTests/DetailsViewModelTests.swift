import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import SwiftUI
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
            let preference = LiveActivityPreferenceStore(userDefaults: defaults)
            var forwarded: [Bool] = []
            let sut = DetailsViewModel(
                location: FakeDetailsLocationSource(),
                liveActivityPreference: preference,
                liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
                setLiveActivityEnabled: { enabled in
                    forwarded.append(enabled)
                    preference.setEnabled(enabled)
                }
            )

            sut.setLiveActivityEnabled(false)
            #expect(sut.isLiveActivityEnabled == false)
            sut.setLiveActivityEnabled(true)
            #expect(sut.isLiveActivityEnabled)
            #expect(forwarded == [false, true])
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
            liveActivityPreference: AppContainer.fixture().liveActivityPreference,
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
            setLiveActivityEnabled: { _ in }
        )
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveActivitySwitchTests {
    @Test("REQ-SURF-008 with Live Activities off in iOS Settings the switch reads off and keeps the driver's choice")
    func systemOffOverridesTheShownStateNotTheChoice() {
        let preference = AppContainer.fixture().liveActivityPreference
        preference.setEnabled(true)
        let sut = DetailsViewModel(
            location: FixedLocation(),
            liveActivityPreference: preference,
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: false),
            setLiveActivityEnabled: { _ in }
        )

        #expect(sut.isLiveActivityAllowedBySystem == false)
        #expect(sut.isLiveActivitySwitchOn == false)
        #expect(sut.isLiveActivityEnabled)
    }

    @Test("REQ-SURF-008 with Live Activities allowed the switch shows the driver's own choice")
    func systemOnShowsTheChoice() {
        let preference = AppContainer.fixture().liveActivityPreference
        let sut = DetailsViewModel(
            location: FixedLocation(),
            liveActivityPreference: preference,
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true),
            setLiveActivityEnabled: { preference.setEnabled($0) }
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
            liveActivityPreference: AppContainer.fixture().liveActivityPreference,
            liveActivityPermission: permission,
            setLiveActivityEnabled: { _ in }
        )
        #expect(sut.isLiveActivityAllowedBySystem)

        let observation = Task { await sut.observeLiveActivityPermission() }
        await permission.waitForSubscriber()
        permission.change(to: false)
        let followed = await eventually(within: .seconds(5)) { sut.isLiveActivityAllowedBySystem == false }
        #expect(followed)
        observation.cancel()
        await observation.value
    }

    @Test("REQ-SURF-008 becoming active re-reads a silent Settings change", arguments: [false, true])
    func activeSceneRefreshesSilentPermissionChange(initiallyAllowed: Bool) async throws {
        let permission = SwitchablePermission(initial: !initiallyAllowed)
        let preference = AppContainer.fixture().liveActivityPreference
        preference.setEnabled(true)
        let sut = DetailsViewModel(
            location: FixedLocation(),
            liveActivityPreference: preference,
            liveActivityPermission: permission,
            setLiveActivityEnabled: { _ in }
        )
        let observation = Task { await sut.observeLiveActivityPermission() }
        defer { observation.cancel() }
        await permission.waitForSubscriber()

        // A distinct streamed value proves the initial replay has drained before the silent change.
        permission.change(to: initiallyAllowed)
        let receivedInitial = await eventually(within: .seconds(5)) {
            sut.isLiveActivityAllowedBySystem == initiallyAllowed
        }
        try #require(receivedInitial)
        #expect(sut.isLiveActivitySwitchOn == initiallyAllowed)

        permission.changeWithoutNotifying(to: !initiallyAllowed)
        #expect(sut.isLiveActivityAllowedBySystem == initiallyAllowed)

        sut.sceneDidChange(isActive: true)

        #expect(sut.isLiveActivityAllowedBySystem == !initiallyAllowed)
        #expect(sut.isLiveActivitySwitchOn == !initiallyAllowed)
        #expect(sut.isLiveActivityEnabled)
        observation.cancel()
        await observation.value
    }

    @Test("REQ-SURF-008 inactive scenes do not re-read permission", arguments: [ScenePhase.inactive, .background])
    func inactiveSceneDoesNotRefreshPermission(phase: ScenePhase) {
        let permission = SwitchablePermission(initial: true)
        let preference = AppContainer.fixture().liveActivityPreference
        preference.setEnabled(true)
        let sut = DetailsViewModel(
            location: FixedLocation(),
            liveActivityPreference: preference,
            liveActivityPermission: permission,
            setLiveActivityEnabled: { _ in }
        )
        let readsBeforePhaseChange = permission.readCount
        permission.changeWithoutNotifying(to: false)

        sut.sceneDidChange(isActive: phase == .active)

        #expect(permission.readCount == readsBeforePhaseChange)
        #expect(sut.isLiveActivityAllowedBySystem)
        #expect(sut.isLiveActivitySwitchOn)
        #expect(sut.isLiveActivityEnabled)
    }

    @Test("SwitchablePermission yields its current state to a late subscriber")
    func switchablePermissionHoldsAChangeForALateSubscriber() async {
        let permission = SwitchablePermission(initial: true)
        permission.change(to: false)

        var iterator = permission.enablementUpdates().makeAsyncIterator()
        let delivered = await iterator.next()
        #expect(delivered == false)
    }

    @Test("REQ-SURF-008 the permission stream reads its first value after subscribing", arguments: [false, true])
    func streamClosesTheSubscriptionWindow(replaysCurrentValue: Bool) async {
        let current = Mutex(true)
        let permission = SystemLiveActivityPermission(
            currentValue: { current.withLock { $0 } },
            updates: {
                SubscriptionWindowUpdates(
                    onSubscribe: { current.withLock { $0 = false } },
                    values: replaysCurrentValue ? [false, true] : [true]
                )
            }
        )
        #expect(permission.areActivitiesEnabled)

        var received: [Bool] = []
        for await enabled in permission.enablementUpdates() {
            received.append(enabled)
        }
        #expect(received == (replaysCurrentValue ? [false, false, true] : [false, true]))
    }

    @Test("REQ-SURF-008 Details receives a Settings flip between its first read and subscription")
    func detailsClosesTheSubscriptionWindow() async {
        let current = Mutex(true)
        let permission = SystemLiveActivityPermission(
            currentValue: { current.withLock { $0 } },
            updates: {
                SubscriptionWindowUpdates(onSubscribe: { current.withLock { $0 = false } }, values: [])
            }
        )
        let preference = AppContainer.fixture().liveActivityPreference
        preference.setEnabled(true)
        let sut = DetailsViewModel(
            location: FixedLocation(),
            liveActivityPreference: preference,
            liveActivityPermission: permission,
            setLiveActivityEnabled: { _ in }
        )
        #expect(sut.isLiveActivityAllowedBySystem)

        await sut.observeLiveActivityPermission()

        #expect(sut.isLiveActivityAllowedBySystem == false)
        #expect(sut.isLiveActivitySwitchOn == false)
        #expect(sut.isLiveActivityEnabled)
    }
}

private struct SubscriptionWindowUpdates: AsyncSequence, Sendable {
    typealias Element = Bool

    let onSubscribe: @Sendable () -> Void
    let values: [Bool]

    func makeAsyncIterator() -> AsyncStream<Bool>.Iterator {
        onSubscribe()
        return AsyncStream { continuation in
            for value in values {
                continuation.yield(value)
            }
            continuation.finish()
        }.makeAsyncIterator()
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

private final class SwitchablePermission: LiveActivityPermissionSource {
    private struct State {
        var current: Bool
        var readCount = 0
        var continuation: AsyncStream<Bool>.Continuation?
        var subscriberWaiters: [CheckedContinuation<Void, Never>] = []
    }

    private let state: Mutex<State>

    init(initial: Bool) {
        state = Mutex(State(current: initial))
    }

    var areActivitiesEnabled: Bool {
        state.withLock {
            $0.readCount += 1
            return $0.current
        }
    }

    var readCount: Int {
        state.withLock { $0.readCount }
    }

    func changeWithoutNotifying(to value: Bool) {
        state.withLock { $0.current = value }
    }

    func enablementUpdates() -> AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream<Bool>.makeStream()
        let waiters = state.withLock {
            $0.continuation = continuation
            continuation.yield($0.current)
            let waiters = $0.subscriberWaiters
            $0.subscriberWaiters = []
            return waiters
        }
        for waiter in waiters {
            waiter.resume()
        }
        return stream
    }

    func waitForSubscriber() async {
        await withCheckedContinuation { waiter in
            let isSubscribed = state.withLock {
                guard $0.continuation == nil else { return true }
                $0.subscriberWaiters.append(waiter)
                return false
            }
            if isSubscribed {
                waiter.resume()
            }
        }
    }

    func change(to value: Bool) {
        state.withLock {
            $0.current = value
            $0.continuation?.yield(value)
        }
    }
}

@MainActor
private final class FakeDetailsLocationSource: HomeLocationSource {
    var isAuthorizationBlocked = false
}
