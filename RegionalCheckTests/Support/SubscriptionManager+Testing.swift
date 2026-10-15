import DriveCheckKit
import Foundation
@testable import RegionalCheck

extension SubscriptionManager {
    /// Persists the entitlement into the test's own suite, never the App Group.
    convenience init(service: any SubscriptionServicing, cache: EntitlementCache, defaults: UserDefaults) {
        self.init(
            service: service,
            cache: cache,
            entitlementPersistence: SharedStore(userDefaults: defaults, legacyDefaults: defaults),
            widgetReloader: TestWidgetReloader()
        )
    }
}
