import Foundation

/// The driver's opt-in and what the server last heard, kept on the device only. A pending delete
/// outlives a failed request, so switching off reaches the server on the next try (REQ-PUSH-003).
struct PushPreferenceStore {
    private enum Key {
        static let enabled = "push.allClear.enabled"
        static let token = "push.allClear.token"
        static let lastSent = "push.allClear.lastSent"
        static let pendingDelete = "push.allClear.pendingDelete"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        nonmutating set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var token: String? {
        get { defaults.string(forKey: Key.token) }
        nonmutating set { defaults.set(newValue, forKey: Key.token) }
    }

    var pendingDeleteToken: String? {
        get { defaults.string(forKey: Key.pendingDelete) }
        nonmutating set { defaults.set(newValue, forKey: Key.pendingDelete) }
    }

    var lastSent: PushRegistration? {
        get {
            defaults.data(forKey: Key.lastSent)
                .flatMap { try? JSONDecoder().decode(PushRegistration.self, from: $0) }
        }
        nonmutating set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.lastSent) }
    }
}
