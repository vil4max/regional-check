import DriveCheckKit
import Foundation

struct EntitlementCache: EntitlementCaching {
    // UserDefaults is documented as thread-safe but is not Sendable; the struct only reads and
    // writes one key through it.
    private nonisolated(unsafe) let defaults: UserDefaults
    private let key = SharedStoreKeys.legacyEntitlement

    /// `legacyDefaults` is where an older build stored the entitlement; production passes
    /// `.standard`. Without it the migration reads the same suite, so a test never touches the
    /// host app's own defaults.
    init(userDefaults: UserDefaults, legacyDefaults: UserDefaults? = nil) {
        defaults = userDefaults
        SharedStore(userDefaults: userDefaults, legacyDefaults: legacyDefaults ?? userDefaults)
            .migrateLegacyEntitlementIfNeeded()
    }

    func load() -> EntitlementSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(EntitlementSnapshot.self, from: data)
    }

    func save(_ snapshot: EntitlementSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
