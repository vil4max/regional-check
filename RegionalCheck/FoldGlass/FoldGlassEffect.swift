import SwiftUI
import UIKit

extension EnvironmentValues {
    /// True while the cold-start overlay hands its hero over to Home: the matched-geometry
    /// hand-off needs Home's real, untilted frame.
    @Entry var foldGlassSuspended = false
}

extension View {
    /// Draws the view under the fold glass (REQ-FG-001...004): turned against the phone's tilt by
    /// perspective, blurred and dimmed with the gap, and exactly flat whenever the gate is closed.
    func foldGlass(source: any MotionProviding, settings: FoldGlassSettings) -> some View {
        modifier(FoldGlassEffect(source: source, settings: settings))
    }
}

/// Built from SwiftUI's own effects, not a Metal shader: the shader needs the Metal Toolchain
/// component, which neither this Mac nor CI installs (owner, 2026-09-23: built-ins now, a shader
/// later as its own lab slice).
private struct FoldGlassEffect: ViewModifier {
    let settings: FoldGlassSettings
    @State private var tracker: FoldGlassTracker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.foldGlassSuspended) private var isSuspended
    @Environment(\.scenePhase) private var scenePhase

    init(source: any MotionProviding, settings: FoldGlassSettings) {
        self.settings = settings
        _tracker = State(initialValue: FoldGlassTracker(source: source))
    }

    private var isActive: Bool {
        FoldGlassGate.isActive(
            isEnabled: settings.isEnabled,
            reduceMotion: reduceMotion,
            isSuspended: isSuspended,
            isSceneActive: scenePhase == .active
        )
    }

    func body(content: Content) -> some View {
        let parameters = isActive ? tracker.parameters : .flat
        // Every effect stays in the tree at its identity value when flat: swapping views in and
        // out would reset the scroll position and state of everything underneath.
        content
            .rotation3DEffect(.radians(parameters.angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .blur(radius: parameters.blurRadius)
            .overlay {
                Color.black
                    .opacity(parameters.dim)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .task(id: isActive) {
                guard isActive else { return }
                await tracker.track(orientation: Self.interfaceOrientation)
            }
    }

    private static func interfaceOrientation() -> FoldGlassOrientation {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        switch scene?.effectiveGeometry.interfaceOrientation {
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }
}
