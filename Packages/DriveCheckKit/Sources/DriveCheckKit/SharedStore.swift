import Foundation

public enum SharedStoreKeys {
    public static let appGroup = "group.vil4max.RegionalCheck"
    public static let snapshot = "shared.snapshot.v1"
    public static let region = "shared.region.v1"
    public static let followsLocation = "shared.region.followsLocation.v1"
    public static let isPro = "shared.entitlement.v1"
    public static let secondaryRegion = "shared.secondaryRegion.v1"
    public static let legacyEntitlement = "subscription.entitlement.v1"
    public static let legacyRegionV2 = "selected_region_v2"
    public static let legacyFollowsLocation = "follows_location_v1"
}

/// Thread-safe key-value store backed by UserDefaults.
///
/// Conforms to `Sendable` for cross-actor access (main app, CarPlay, widgets).
/// Individual UserDefaults reads/writes are thread-safe. Compound operations
/// (load → decode) are not atomic, but each method performs a single read or
/// write per key, so concurrent calls from different actors are safe.
public struct SharedStore: Sendable {
    public static let shared = SharedStore()

    private nonisolated(unsafe) let defaults: UserDefaults
    private nonisolated(unsafe) let legacyDefaults: UserDefaults

    public init(
        userDefaults: UserDefaults? = UserDefaults(suiteName: SharedStoreKeys.appGroup),
        legacyDefaults: UserDefaults = .standard
    ) {
        defaults = userDefaults ?? .standard
        self.legacyDefaults = legacyDefaults
    }

    public func saveSnapshot(_ snapshot: AlertsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: SharedStoreKeys.snapshot)
    }

    public func loadSnapshot() -> AlertsSnapshot? {
        guard let data = defaults.data(forKey: SharedStoreKeys.snapshot) else { return nil }
        return try? JSONDecoder().decode(AlertsSnapshot.self, from: data)
    }

    public func saveRegion(_ region: AlertRegion) {
        guard let data = try? JSONEncoder().encode(region) else { return }
        defaults.set(data, forKey: SharedStoreKeys.region)
    }

    public func loadRegion() -> AlertRegion? {
        guard let data = defaults.data(forKey: SharedStoreKeys.region) else { return nil }
        return try? JSONDecoder().decode(AlertRegion.self, from: data)
    }

    public func saveFollowsLocation(_ follows: Bool) {
        defaults.set(follows, forKey: SharedStoreKeys.followsLocation)
    }

    public func loadFollowsLocation() -> Bool {
        if defaults.object(forKey: SharedStoreKeys.followsLocation) == nil {
            return true
        }
        return defaults.bool(forKey: SharedStoreKeys.followsLocation)
    }

    public func saveIsPro(_ isPro: Bool) {
        defaults.set(isPro, forKey: SharedStoreKeys.isPro)
    }

    public func loadIsPro() -> Bool {
        defaults.bool(forKey: SharedStoreKeys.isPro)
    }

    public func saveSecondaryRegion(_ region: AlertRegion?) {
        if let region {
            guard let data = try? JSONEncoder().encode(region) else { return }
            defaults.set(data, forKey: SharedStoreKeys.secondaryRegion)
        } else {
            defaults.removeObject(forKey: SharedStoreKeys.secondaryRegion)
        }
    }

    public func loadSecondaryRegion() -> AlertRegion? {
        guard let data = defaults.data(forKey: SharedStoreKeys.secondaryRegion) else { return nil }
        return try? JSONDecoder().decode(AlertRegion.self, from: data)
    }

    public func migrateLegacyRegionIfNeeded() {
        guard loadRegion() == nil else { return }

        if let data = legacyDefaults.data(forKey: SharedStoreKeys.legacyRegionV2),
           let region = try? JSONDecoder().decode(AlertRegion.self, from: data) {
            saveRegion(region)
            legacyDefaults.removeObject(forKey: SharedStoreKeys.legacyRegionV2)
            if legacyDefaults.object(forKey: SharedStoreKeys.legacyFollowsLocation) != nil {
                saveFollowsLocation(legacyDefaults.bool(forKey: SharedStoreKeys.legacyFollowsLocation))
                legacyDefaults.removeObject(forKey: SharedStoreKeys.legacyFollowsLocation)
            }
            return
        }

        guard let legacyData = legacyDefaults.data(forKey: "selected_region_v1"),
              let legacy = try? JSONDecoder().decode(LegacyAlertRegion.self, from: legacyData),
              let region = legacy.resolved
        else {
            return
        }
        saveRegion(region)
        legacyDefaults.removeObject(forKey: "selected_region_v1")
    }

    public func migrateLegacyEntitlementIfNeeded() {
        guard defaults.data(forKey: SharedStoreKeys.legacyEntitlement) == nil,
              let data = legacyDefaults.data(forKey: SharedStoreKeys.legacyEntitlement)
        else {
            return
        }
        defaults.set(data, forKey: SharedStoreKeys.legacyEntitlement)
        legacyDefaults.removeObject(forKey: SharedStoreKeys.legacyEntitlement)
    }
}

private struct LegacyAlertRegion: Decodable {
    enum Kind: Decodable {
        case kyivCity
        case oblast(name: String)
    }

    let kind: Kind

    var resolved: AlertRegion? {
        switch kind {
        case .kyivCity:
            .kyivCity
        case let .oblast(name):
            AlertRegion.from(apiKey: name) ?? .kyivCity
        }
    }
}
