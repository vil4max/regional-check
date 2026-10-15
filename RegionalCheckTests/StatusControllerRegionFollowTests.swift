import DriveCheckKit
import Foundation
import Observation
@testable import RegionalCheck
import Testing

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct StatusControllerRegionFollowTests {
    @Test("REQ-PROVIDER-002 status applies the owner's current value when following starts, with one request")
    func registrationAppliesCurrentValue() async {
        let harness = RegionFollowHarness()
        harness.source.selectedRegion = .kharkiv

        harness.controller.follow(harness.source)

        #expect(harness.controller.currentRegion == .kharkiv)
        #expect(harness.controller.regionTitle == AlertRegion.kharkiv.title)
        #expect(harness.controller.state.phase == .alarm)
        await harness.reloader.waitForCount(2)
        #expect(harness.network.alertRequestCount == 1)
        #expect(harness.reloader.reloadCount == 2)
    }

    @Test("REQ-PROVIDER-002 status follows committed values and coalesces changes into one request")
    func changesApplyCachedStatusThenRefreshOnce() async {
        let harness = RegionFollowHarness()
        harness.controller.follow(harness.source)
        #expect(harness.reloader.reloadCount == 0)

        harness.source.selectedRegion = .lviv
        harness.source.selectedRegion = .kharkiv
        #expect(harness.queue.count == 1)
        harness.queue.drain()

        #expect(harness.controller.currentRegion == .kharkiv)
        #expect(harness.controller.state.phase == .alarm)
        #expect(harness.network.alertRequestCount == 0)
        #expect(harness.reloader.reloadCount == 1)
        await harness.reloader.waitForCount(2)
        #expect(harness.network.alertRequestCount == 1)
        #expect(harness.reloader.reloadCount == 2)

        harness.source.selectedRegion = .lviv
        harness.queue.drain()
        #expect(harness.controller.currentRegion == .lviv)
        #expect(harness.controller.state.phase == .quiet)
    }

    @Test("A second region follower registration reports a programming error and keeps the first source")
    func duplicateRegistrationIsRejected() {
        var failures = 0
        let harness = RegionFollowHarness(duplicateFollow: { failures += 1 })
        harness.controller.follow(harness.source)
        let other = FollowRegionSource()
        other.selectedRegion = .kharkiv

        harness.controller.follow(other)
        other.selectedRegion = .lviv

        #expect(failures == 1)
        #expect(harness.controller.currentRegion == .kyivCity)
        #expect(harness.queue.isEmpty)
        harness.source.selectedRegion = .kharkiv
        #expect(harness.queue.count == 1)
    }

    @Test("Releasing the status follower discards an already queued region change")
    func releasedControllerDoesNotRefreshOrReload() {
        let queue = ScheduledChangeQueue()
        let network = FixtureNetwork()
        let reloader = RegionReloadSpy()
        let source = FollowRegionSource()
        var controller: StatusController? = StatusController(
            region: .kyivCity,
            provider: UbillingProvider(httpClient: network),
            environmentProvider: FixtureRefreshEnvironment(),
            persistence: RegionSnapshotStore(network: network),
            widgetReloader: reloader,
            scheduleRegionChange: { queue.enqueue($0) }
        )
        weak var released = controller
        controller?.follow(source)
        source.selectedRegion = .kharkiv
        #expect(queue.count == 1)
        controller = nil

        queue.drain()

        #expect(released == nil)
        #expect(network.alertRequestCount == 0)
        #expect(reloader.reloadCount == 0)
        source.selectedRegion = .lviv
        #expect(queue.isEmpty)
    }
}

@MainActor
@Observable
private final class FollowRegionSource: CurrentRegionSource {
    var selectedRegion = AlertRegion.kyivCity
}

@MainActor
private final class RegionFollowHarness {
    let source = FollowRegionSource()
    let queue = ScheduledChangeQueue()
    let network = FixtureNetwork()
    let reloader = RegionReloadSpy()
    let controller: StatusController

    init(duplicateFollow: @escaping @MainActor () -> Void = { Issue.record("Unexpected duplicate follow") }) {
        controller = StatusController(
            region: .kyivCity,
            provider: UbillingProvider(httpClient: network, now: { FixtureNetwork.servedAt }),
            environmentProvider: FixtureRefreshEnvironment(),
            persistence: RegionSnapshotStore(network: network),
            widgetReloader: reloader,
            now: { FixtureNetwork.servedAt },
            scheduleRegionChange: { [queue] in queue.enqueue($0) },
            duplicateRegionFollow: duplicateFollow
        )
    }
}

@MainActor
private final class RegionSnapshotStore: StatusPersisting {
    private var snapshot: AlertsSnapshot

    init(network: FixtureNetwork) {
        snapshot = network.snapshot(fetchedAt: FixtureNetwork.servedAt)
    }

    func saveSnapshot(_ snapshot: AlertsSnapshot) { self.snapshot = snapshot }
    func loadSnapshot() -> AlertsSnapshot? { snapshot }
}

@MainActor
final class RegionReloadSpy: WidgetReloading {
    private(set) var reloadCount = 0
    private var waiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func reloadAllTimelines() {
        reloadCount += 1
        let ready = waiters.filter { $0.count <= reloadCount }
        waiters.removeAll { $0.count <= reloadCount }
        for waiter in ready { waiter.continuation.resume() }
    }

    func waitForCount(_ expected: Int) async {
        guard reloadCount < expected else { return }
        await withCheckedContinuation { waiters.append((expected, $0)) }
    }
}
