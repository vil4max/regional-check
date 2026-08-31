import Foundation
@testable import RegionalCheck
import Testing

struct EntitlementStreamTests {
    @Test
    @MainActor
    func entitlementChanges_notifiesOnGrantAndRevoke() async {
        let service = FakeSubscriptionService(products: [], entitlement: .none)
        let manager = SubscriptionManager(
            service: service,
            cache: EntitlementCache(),
            widgetReloader: TestWidgetReloader()
        )
        let stream = manager.entitlementChanges()
        var notifications = 0
        let consumer = Task { @MainActor in
            for await _ in stream {
                notifications += 1
            }
        }
        await manager.start()
        try? await Task.sleep(for: .milliseconds(50))

        service.push(.active(TestFixtures.activeEntitlement))
        await waitForNotificationCount(&notifications, atLeast: 1)
        #expect(notifications >= 1)

        service.push(.none)
        await waitForNotificationCount(&notifications, atLeast: 2)
        #expect(notifications >= 2)

        consumer.cancel()
    }
}

@MainActor
private func waitForNotificationCount(_ count: inout Int, atLeast target: Int) async {
    for _ in 0 ..< 50 where count < target {
        try? await Task.sleep(for: .milliseconds(20))
    }
}
