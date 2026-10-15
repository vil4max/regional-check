import Foundation
import Synchronization
import Testing

extension TestDefaults {
    /// A unique defaults suite for `AppContainer.fixture(defaultsSuite:)`, removed when the current
    /// test ends. The fixture clears its suite only before use, so without this every test would
    /// leave a preferences file in the host app's container. The test or its suite must carry
    /// `.removesDefaultsSuites`.
    static func fixtureSuite(_ label: String) -> String {
        let name = "RegionalCheckTests.\(label).\(UUID().uuidString)"
        if let registry = DefaultsSuiteRegistry.current {
            registry.add(name)
        } else {
            Issue.record("Add .removesDefaultsSuites to the suite that creates the \(label) fixture")
        }
        return name
    }
}

final class DefaultsSuiteRegistry: Sendable {
    @TaskLocal static var current: DefaultsSuiteRegistry?

    private let names = Mutex<[String]>([])

    func add(_ name: String) {
        names.withLock { $0.append(name) }
    }

    func removeAll() {
        for name in names.withLock({ $0 }) {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
    }
}

/// Removes every suite a test created through `TestDefaults.fixtureSuite(_:)` once it ends,
/// whether it passed, failed or threw.
struct RemovesDefaultsSuitesTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for _: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        // A suite-level scope wraps all of its tests; the registry belongs to each test case.
        guard testCase != nil else { return try await function() }
        let registry = DefaultsSuiteRegistry()
        defer { registry.removeAll() }
        try await DefaultsSuiteRegistry.$current.withValue(registry, operation: function)
    }
}

extension Trait where Self == RemovesDefaultsSuitesTrait {
    static var removesDefaultsSuites: Self { Self() }
}
