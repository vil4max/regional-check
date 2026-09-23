import Foundation
import Observation

/// Feeds motion samples through `FoldGlassModel` for Home. The first sample is the zero pose, so
/// the effect calibrates to however the phone is held when Home appears.
@MainActor
@Observable
final class FoldGlassTracker {
    private(set) var parameters: FoldGlassParameters = .flat
    private let source: any MotionProviding

    init(source: any MotionProviding) {
        self.source = source
    }

    /// Runs until the motion stream ends or the calling task is cancelled, and always leaves
    /// the interface flat afterwards (REQ-FG-003). A new orientation means a new run, so the
    /// zero pose is taken again after the phone is rotated.
    func track(orientation: FoldGlassOrientation) async {
        var zero: DeviceAttitude?
        for await attitude in source.attitudes() {
            let base = zero ?? attitude
            zero = base
            let next = FoldGlassModel.parameters(attitude: attitude, zero: base, orientation: orientation)
            if next != parameters {
                parameters = next
            }
        }
        parameters = .flat
    }
}
