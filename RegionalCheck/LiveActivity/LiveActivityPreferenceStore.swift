import Foundation
import Observation

@MainActor
protocol LiveActivityPreferenceReading {
    var isEnabled: Bool { get }
    func changes() -> AsyncStream<Void>
}

@MainActor
protocol LiveActivityPreferenceWriting {
    func setEnabled(_ enabled: Bool)
}

@MainActor
@Observable
final class LiveActivityPreferenceStore: LiveActivityPreferenceReading, LiveActivityPreferenceWriting {
    private static let key = "subscription.liveActivity.enabled"
    private let defaults: UserDefaults
    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    private(set) var isEnabled: Bool

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        isEnabled = userDefaults.object(forKey: Self.key) as? Bool ?? true
    }

    func setEnabled(_ enabled: Bool) {
        let previous = isEnabled
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.key)
        guard previous != enabled else { return }
        for continuation in continuations.values { continuation.yield() }
    }

    isolated deinit {
        for continuation in continuations.values { continuation.finish() }
    }

    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations.removeValue(forKey: id)
                }
            }
        }
    }
}
