import DriveCheckKit
import Foundation

/// The package's own copy of the app tests' helpers: this target runs without the app host
/// and cannot see RegionalCheckTests' support files.
enum TestDefaults {
    static func withTemporaryDefaults<T>(
        suiteName: String = "DriveCheckKitTests.\(UUID().uuidString)",
        _ operation: (UserDefaults) throws -> T
    ) rethrows -> T {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Missing UserDefaults suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        return try operation(defaults)
    }

    /// `#isolation` keeps the operation on the caller's actor, so a closure that captures
    /// actor-isolated state is not sent across an isolation boundary.
    static func withTemporaryDefaults<T>(
        suiteName: String = "DriveCheckKitTests.\(UUID().uuidString)",
        isolation _: isolated (any Actor)? = #isolation,
        _ operation: (UserDefaults) async throws -> T
    ) async rethrows -> T {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Missing UserDefaults suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        return try await operation(defaults)
    }
}

enum TestFixtures {
    static func quietSnapshot(
        region: AlertRegion = .kyivCity,
        checkedAt: Date = Date(timeIntervalSince1970: 1)
    ) -> AlertsSnapshot {
        AlertsSnapshot(
            source: "test",
            serverCachedAt: checkedAt,
            fetchedAt: checkedAt,
            statuses: [region: .quiet]
        )
    }
}

struct MockStatusProvider: StatusProviding {
    var snapshot: AlertsSnapshot?
    var error: (any Error)?

    func fetchAlerts() async throws -> AlertsSnapshot {
        if let error {
            throw error
        }
        guard let snapshot else {
            struct MissingSnapshot: Error {}
            throw MissingSnapshot()
        }
        return snapshot
    }
}
