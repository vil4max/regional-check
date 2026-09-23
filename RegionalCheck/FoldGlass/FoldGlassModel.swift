import Foundation

/// Device attitude in radians, as Core Motion reports it: `roll` turns around the device's long
/// (Y) axis, `pitch` around its short (X) axis.
struct DeviceAttitude: Equatable, Sendable {
    var roll: Double
    var pitch: Double
}

/// The interface orientation the tilt is measured against; mirrors `UIInterfaceOrientation`
/// so the model stays free of UIKit.
enum FoldGlassOrientation: Sendable {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
}

/// How Home is drawn under the fold glass for one motion sample.
struct FoldGlassParameters: Equatable, Sendable {
    /// Rotation of the interface plane around the screen's vertical axis, in radians.
    let angle: Double
    /// Frosted-glass blur, in points.
    let blurRadius: Double
    /// Darkening toward black, 0...1.
    let dim: Double

    static let flat = FoldGlassParameters(angle: 0, blurRadius: 0, dim: 0)
}

/// REQ-FG-003, REQ-FG-004: turns a tilt away from the calibrated zero pose into the fold glass
/// parameters. The interface keeps the plane it had at the zero pose, so it rotates against the
/// tilt; the gap to the glass grows with the angle and so do blur and dim, up to ceilings that
/// keep the status hero readable at every tilt.
enum FoldGlassModel {
    /// The tilt at which the effect reaches its ceilings (18°); larger tilts change nothing.
    static let maxAngle = 18 * Double.pi / 180
    /// Legibility ceilings (owner, 2026-09-23: the status text is never allowed to become
    /// unreadable). Confirmed on a device in the TestFlight pass.
    static let maxBlurRadius = 2.0
    static let maxDim = 0.18
    /// Tilts below 1° are sensor noise, and a flat interface costs nothing to render.
    static let deadZone = Double.pi / 180

    static func parameters(
        attitude: DeviceAttitude?,
        zero: DeviceAttitude?,
        orientation: FoldGlassOrientation
    ) -> FoldGlassParameters {
        guard let attitude, let zero else { return .flat }
        let tilt = screenTilt(attitude: attitude, zero: zero, orientation: orientation)
        guard abs(tilt) >= deadZone else { return .flat }
        let clamped = min(max(tilt, -maxAngle), maxAngle)
        let gap = abs(clamped) / maxAngle
        return FoldGlassParameters(angle: -clamped, blurRadius: maxBlurRadius * gap, dim: maxDim * gap)
    }

    /// The tilt around the screen's vertical axis. In portrait that axis is the device's Y
    /// axis (roll); in landscape it is the device's X axis (pitch). The landscape signs follow
    /// the device's rotation into each orientation and are checked on a device.
    static func screenTilt(
        attitude: DeviceAttitude,
        zero: DeviceAttitude,
        orientation: FoldGlassOrientation
    ) -> Double {
        let roll = wrapped(attitude.roll - zero.roll)
        let pitch = wrapped(attitude.pitch - zero.pitch)
        switch orientation {
        case .portrait: return roll
        case .portraitUpsideDown: return -roll
        case .landscapeLeft: return pitch
        case .landscapeRight: return -pitch
        }
    }

    /// The same angle within -π...π, so a roll across the ±180° seam is not a full turn.
    private static func wrapped(_ angle: Double) -> Double {
        atan2(sin(angle), cos(angle))
    }
}
