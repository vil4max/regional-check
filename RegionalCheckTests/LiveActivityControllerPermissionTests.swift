import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct LiveActivityControllerPermissionTests {
    @Test("REQ-SURF-008 controller eligibility follows the injected permission", arguments: [false, true])
    func eligibilityUsesInjectedPermission(allowed: Bool) {
        let permission = ControllerPermission(initial: allowed)
        let controller = LiveActivityController(
            allowsLiveActivity: { true },
            entitlementChanges: { AsyncStream { $0.finish() } },
            liveActivityPermission: permission
        )

        #expect(controller.canRunActivity == allowed)
        #expect(permission.readCount == 1)
        permission.change(to: !allowed)
        #expect(controller.canRunActivity == !allowed)
        #expect(permission.readCount == 2)
        permission.finish()
    }

    @Test("REQ-SURF-008 the driver's preference still gates a permitted activity")
    func driverPreferenceStillGatesPermission() {
        let controller = LiveActivityController(
            allowsLiveActivity: { false },
            entitlementChanges: { AsyncStream { $0.finish() } },
            liveActivityPermission: FixedLiveActivityPermission(areActivitiesEnabled: true)
        )

        #expect(!controller.canRunActivity)
    }

    @Test("REQ-SURF-008 the fixture permission controls both Details and the activity", arguments: [false, true])
    func fixtureSharesPermission(allowed: Bool) {
        let container = AppContainer.fixture(
            defaultsSuite: "LiveActivityControllerPermissionTests.\(UUID().uuidString)",
            liveActivitiesAllowed: allowed
        )
        container.subscription.setLiveActivityEnabled(true)

        #expect(container.liveActivity.canRunActivity == allowed)
        #expect(container.detailsViewModel.isLiveActivityAllowedBySystem == allowed)
    }

    @Test("REQ-SURF-008 permission changes reconcile without a content or preference update")
    func permissionUpdatesReconcile() async {
        let permission = ControllerPermission(initial: true)
        defer { permission.finish() }
        let controller = LiveActivityController(
            allowsLiveActivity: { true },
            entitlementChanges: { AsyncStream { $0.finish() } },
            liveActivityPermission: permission
        )
        var reads = permission.reads.stream.makeAsyncIterator()
        #expect(await reads.next() == true)
        await controller.settle()

        permission.change(to: false)
        #expect(await reads.next() == false)
        await controller.settle()

        permission.change(to: true)
        #expect(await reads.next() == true)
        await controller.settle()
    }

    @Test("Releasing the controller cancels permission observation")
    func releasingControllerCancelsObservation() async {
        let permission = ControllerPermission(initial: true)
        defer { permission.finish() }
        var controller: LiveActivityController? = LiveActivityController(
            allowsLiveActivity: { true },
            entitlementChanges: { AsyncStream { $0.finish() } },
            liveActivityPermission: permission
        )
        weak var releasedController = controller
        var reads = permission.reads.stream.makeAsyncIterator()
        #expect(await reads.next() == true)
        await controller?.settle()

        controller = nil

        var cancellations = permission.cancellations.stream.makeAsyncIterator()
        #expect(await cancellations.next() == true)
        #expect(releasedController == nil)
    }
}

private final class ControllerPermission: LiveActivityPermissionSource {
    private struct State {
        var enabled: Bool
        var reads = 0
    }

    private let state: Mutex<State>
    private let updates = AsyncStream<Bool>.makeStream()
    let reads = AsyncStream<Bool>.makeStream()
    let cancellations = AsyncStream<Bool>.makeStream()

    init(initial: Bool) {
        state = Mutex(State(enabled: initial))
        let cancellation = cancellations.continuation
        updates.continuation.onTermination = { @Sendable termination in
            if case .cancelled = termination {
                cancellation.yield(true)
            }
            cancellation.finish()
        }
    }

    var readCount: Int { state.withLock { $0.reads } }

    var areActivitiesEnabled: Bool {
        let enabled = state.withLock {
            $0.reads += 1
            return $0.enabled
        }
        reads.continuation.yield(enabled)
        return enabled
    }

    func enablementUpdates() -> AsyncStream<Bool> {
        updates.continuation.yield(state.withLock { $0.enabled })
        return updates.stream
    }

    func change(to enabled: Bool) {
        state.withLock { $0.enabled = enabled }
        updates.continuation.yield(enabled)
    }

    func finish() {
        updates.continuation.finish()
        reads.continuation.finish()
    }
}
