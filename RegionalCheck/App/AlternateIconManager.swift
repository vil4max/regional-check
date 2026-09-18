import UIKit

/// What changing the app icon needs from the app object. A protocol boundary so a test can observe
/// the calls: `UIApplication` is the only production conformance.
@MainActor
protocol AlternateIconPresenting {
    var supportsAlternateIcons: Bool { get }
    var alternateIconName: String? { get }
    func applyAlternateIconName(_ name: String?)
}

/// `applyAlternateIconName`, not `setAlternateIconName`: `UIApplication` already declares the latter
/// twice — with a completion handler and as `async throws` — and a requirement of that name would be
/// ambiguous at the conformance.
extension UIApplication: AlternateIconPresenting {
    func applyAlternateIconName(_ name: String?) {
        setAlternateIconName(name) { _ in }
    }
}

enum AlternateIconManager {
    static let proIconName = "AppIcon-Pro"

    @MainActor
    static func sync(isPro: Bool, presenter: (any AlternateIconPresenting)? = nil) {
        // Two branches on purpose, and not to be collapsed: the default path keeps the unit-test
        // guard because `UIApplication` raises the system icon-change alert, while an injected
        // presenter cannot — guarding that one too would make every test assert against a no-op,
        // which is how this file ended up with no test at all.
        let target: any AlternateIconPresenting
        if let presenter {
            target = presenter
        } else {
            guard !HostProcess.isUnitTesting else { return }
            target = UIApplication.shared
        }

        guard target.supportsAlternateIcons else { return }
        let desired = isPro ? proIconName : nil
        guard target.alternateIconName != desired else { return }
        target.applyAlternateIconName(desired)
    }
}
