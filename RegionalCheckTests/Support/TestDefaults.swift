import Foundation

enum TestDefaults {
    static func withTemporaryDefaults<T>(
        suiteName: String = "RegionalCheckTests.\(UUID().uuidString)",
        _ operation: (UserDefaults) throws -> T
    ) rethrows -> T {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Missing UserDefaults suite \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        return try operation(defaults)
    }

    /// `#isolation` keeps the operation on the caller's actor. Most callers are `@MainActor` tests
    /// whose closures capture main-actor state, and without it Swift 6 treats the call as sending a
    /// non-Sendable closure across an isolation boundary.
    static func withTemporaryDefaults<T>(
        suiteName: String = "RegionalCheckTests.\(UUID().uuidString)",
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

/// The test plans pin the language to English, so this only runs its operation. It used to write
/// `AppleLanguages` into the host app's defaults and restore the system list there, which pinned
/// the app's language on the simulator after a test run. Remove it once no test calls it.
enum TestLocale {
    static func english<T>(_ operation: () throws -> T) rethrows -> T {
        try operation()
    }
}
