import Foundation

/// Device attitude as Core Motion's unit quaternion (`CMAttitude.quaternion`): the rotation from
/// the reference frame to the device. A quaternion, not Euler roll and pitch, because Euler roll
/// swings wildly when the phone is held upright (gimbal lock), exactly how a phone is held.
struct DeviceAttitude: Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double
    var w: Double

    static let identity = DeviceAttitude(x: 0, y: 0, z: 0, w: 1)

    /// A rotation by `angle` radians around the device's X (short) or Y (long) axis.
    static func rotation(aroundX angle: Double) -> DeviceAttitude {
        DeviceAttitude(x: sin(angle / 2), y: 0, z: 0, w: cos(angle / 2))
    }

    static func rotation(aroundY angle: Double) -> DeviceAttitude {
        DeviceAttitude(x: 0, y: sin(angle / 2), z: 0, w: cos(angle / 2))
    }

    /// `self` followed by `other`, with `other` expressed in the device frame of `self`.
    func then(_ other: DeviceAttitude) -> DeviceAttitude {
        DeviceAttitude(
            x: w * other.x + x * other.w + y * other.z - z * other.y,
            y: w * other.y - x * other.z + y * other.w + z * other.x,
            z: w * other.z + x * other.y - y * other.x + z * other.w,
            w: w * other.w - x * other.x - y * other.y - z * other.z
        )
    }

    var inverse: DeviceAttitude {
        DeviceAttitude(x: -x, y: -y, z: -z, w: w)
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
        var relative = zero.inverse.then(attitude)
        // q and -q are the same rotation; the one with w >= 0 gives a twist within -π...π.
        if relative.w < 0 {
            relative = DeviceAttitude(x: -relative.x, y: -relative.y, z: -relative.z, w: -relative.w)
        }
        let aroundY = 2 * atan2(relative.y, relative.w)
        let aroundX = 2 * atan2(relative.x, relative.w)
        switch orientation {
        case .portrait: return aroundY
        case .portraitUpsideDown: return -aroundY
        case .landscapeLeft: return aroundX
        case .landscapeRight: return -aroundX
        }
    }
}
