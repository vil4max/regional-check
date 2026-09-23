import Foundation
import simd

/// Device attitude as Core Motion's unit quaternion (`CMAttitude.quaternion`): the rotation from
/// the reference frame to the device. A quaternion, not Euler roll and pitch, because Euler roll
/// swings wildly when the phone is held upright (gimbal lock), exactly how a phone is held.
struct DeviceAttitude: Equatable, Sendable {
    var quaternion: simd_quatd

    static let identity = DeviceAttitude(quaternion: simd_quatd(ix: 0, iy: 0, iz: 0, r: 1))

    /// A rotation by `angle` radians around the device's X (short) or Y (long) axis.
    static func rotation(aroundX angle: Double) -> DeviceAttitude {
        DeviceAttitude(quaternion: simd_quatd(angle: angle, axis: SIMD3(1, 0, 0)))
    }

    static func rotation(aroundY angle: Double) -> DeviceAttitude {
        DeviceAttitude(quaternion: simd_quatd(angle: angle, axis: SIMD3(0, 1, 0)))
    }

    /// `self` followed by `other`, with `other` expressed in the device frame of `self`.
    func then(_ other: DeviceAttitude) -> DeviceAttitude {
        DeviceAttitude(quaternion: quaternion * other.quaternion)
    }

    var inverse: DeviceAttitude {
        DeviceAttitude(quaternion: quaternion.inverse)
    }
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

    /// The tilt around the screen's vertical axis since the zero pose: the twist of the
    /// relative rotation around that axis (swing-twist decomposition), which stays well defined
    /// at any pitch. In portrait the axis is the device's Y axis; in landscape it is the X axis.
    /// The landscape signs follow the device's rotation into each orientation and are checked
    /// on a device.
    static func screenTilt(
        attitude: DeviceAttitude,
        zero: DeviceAttitude,
        orientation: FoldGlassOrientation
    ) -> Double {
        var relative = zero.inverse.then(attitude).quaternion
        // q and -q are the same rotation; the one with a non-negative real part keeps the twist
        // within a half turn.
        if relative.real < 0 {
            relative = simd_quatd(vector: -relative.vector)
        }
        let aroundY = 2 * atan2(relative.imag.y, relative.real)
        let aroundX = 2 * atan2(relative.imag.x, relative.real)
        switch orientation {
        case .portrait: return aroundY
        case .portraitUpsideDown: return -aroundY
        case .landscapeLeft: return aroundX
        case .landscapeRight: return -aroundX
        }
    }
}
