import Combine
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
    let source: any MotionProviding
    let settings: FoldGlassSettings
    /// Built on the first tracking run rather than in `init`: the modifier is re-created on every
    /// HomeView render, and `State(initialValue:)` would build a tracker each time to discard it.
    @State private var tracker: FoldGlassTracker?
    @State private var orientation = FoldGlassEffect.interfaceOrientation()
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.foldGlassSuspended) private var isSuspended
    @Environment(\.scenePhase) private var scenePhase

    private struct TrackingKey: Equatable {
        let isActive: Bool
        let orientation: FoldGlassOrientation
    }

    private var isActive: Bool {
        FoldGlassGate.isActive(
            isEnabled: settings.isEnabled,
            reduceMotion: reduceMotion,
            isSuspended: isSuspended,
            isSceneActive: scenePhase == .active,
            isLowPowerMode: isLowPowerMode
        )
    }

    func body(content: Content) -> some View {
        let parameters = isActive ? tracker?.parameters ?? .flat : .flat
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
            // The power-state notification may arrive on any thread; view state changes on main.
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .NSProcessInfoPowerStateDidChange)
                    .receive(on: DispatchQueue.main)
            ) { _ in
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            // The screen's vertical axis moves with the interface; read it on rotation, not on
            // every motion sample. A size change catches portrait to landscape once layout has
            // settled; the device notification catches a half turn, which keeps the size.
            .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in
                orientation = Self.interfaceOrientation()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                orientation = Self.interfaceOrientation()
            }
            .task(id: TrackingKey(isActive: isActive, orientation: orientation)) {
                guard isActive else { return }
                let tracker = tracker ?? FoldGlassTracker(source: source)
                self.tracker = tracker
                await tracker.track(orientation: orientation)
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
