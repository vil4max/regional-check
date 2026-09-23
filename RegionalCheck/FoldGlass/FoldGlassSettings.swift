import Foundation
import Observation

/// REQ-FG-001: the driver's fold glass switch on Details. On until they turn it off; phone-only,
/// so it lives in the app's own defaults, not the widget-shared store.
@MainActor
@Observable
final class FoldGlassSettings {
    private static let enabledKey = "foldGlass.enabled"
    private let userDefaults: UserDefaults

    var isEnabled: Bool {
        didSet { userDefaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        isEnabled = userDefaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }
}

/// Whether Home is drawn under the fold glass at all. Reduce Motion always wins (REQ-FG-002);
/// the cold-start overlay and a scene in the background keep Home flat too.
enum FoldGlassGate {
    static func isActive(isEnabled: Bool, reduceMotion: Bool, isSuspended: Bool, isSceneActive: Bool) -> Bool {
        isEnabled && !reduceMotion && !isSuspended && isSceneActive
    }
}
