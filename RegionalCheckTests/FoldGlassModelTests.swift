import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct FoldGlassModelTests {
    private static let zero = DeviceAttitude(roll: 0.1, pitch: -0.2)

    private static func tilted(roll: Double = 0, pitch: Double = 0) -> DeviceAttitude {
        DeviceAttitude(roll: zero.roll + roll, pitch: zero.pitch + pitch)
    }

    @Test("REQ-FG-003 without a motion sample the interface is flat")
    func noMotionIsFlat() {
        #expect(FoldGlassModel.parameters(attitude: nil, zero: Self.zero, orientation: .portrait) == .flat)
        #expect(FoldGlassModel.parameters(attitude: Self.zero, zero: nil, orientation: .portrait) == .flat)
    }

    @Test("REQ-FG-003 the zero pose and sensor noise leave the interface flat")
    func zeroPoseIsFlat() {
        #expect(FoldGlassModel.parameters(attitude: Self.zero, zero: Self.zero, orientation: .portrait) == .flat)
        let noise = Self.tilted(roll: 0.005)
        #expect(FoldGlassModel.parameters(attitude: noise, zero: Self.zero, orientation: .portrait) == .flat)
    }

    @Test("REQ-FG-004 blur and dim never pass their legibility ceiling, whatever the tilt")
    func tiltIsClamped() {
        for roll in stride(from: -3.1, through: 3.1, by: 0.05) {
            let parameters = FoldGlassModel.parameters(
                attitude: Self.tilted(roll: roll),
                zero: Self.zero,
                orientation: .portrait
            )
            #expect(abs(parameters.angle) <= FoldGlassModel.maxAngle + 1e-9)
            #expect(parameters.blurRadius <= FoldGlassModel.maxBlurRadius + 1e-9)
            #expect(parameters.dim <= FoldGlassModel.maxDim + 1e-9)
            #expect(parameters.blurRadius >= 0 && parameters.dim >= 0)
        }
        let extreme = FoldGlassModel.parameters(
            attitude: Self.tilted(roll: 1.5),
            zero: Self.zero,
            orientation: .portrait
        )
        #expect(extreme.blurRadius == FoldGlassModel.maxBlurRadius)
        #expect(extreme.dim == FoldGlassModel.maxDim)
    }

    @Test("REQ-FG-004 the interface counter-rotates so it keeps the plane of the zero pose")
    func planeStaysPut() {
        let right = FoldGlassModel.parameters(attitude: Self.tilted(roll: 0.1), zero: Self.zero, orientation: .portrait)
        let left = FoldGlassModel.parameters(attitude: Self.tilted(roll: -0.1), zero: Self.zero, orientation: .portrait)
        #expect(right.angle < 0)
        #expect(left.angle > 0)
        #expect(abs(right.angle + 0.1) < 1e-9)
        #expect(right.blurRadius > 0 && right.blurRadius < FoldGlassModel.maxBlurRadius)
    }

    @Test("REQ-FG-004 the screen's vertical axis follows the interface orientation")
    func orientationPicksTheAxis() {
        let rolled = Self.tilted(roll: 0.1)
        let pitched = Self.tilted(pitch: 0.1)
        #expect(FoldGlassModel.parameters(attitude: pitched, zero: Self.zero, orientation: .portrait) == .flat)
        #expect(FoldGlassModel.parameters(attitude: rolled, zero: Self.zero, orientation: .landscapeLeft) == .flat)
        let left = FoldGlassModel.parameters(attitude: pitched, zero: Self.zero, orientation: .landscapeLeft)
        let right = FoldGlassModel.parameters(attitude: pitched, zero: Self.zero, orientation: .landscapeRight)
        #expect(left.angle == -right.angle && left.angle != 0)
        let upsideDown = FoldGlassModel.parameters(attitude: rolled, zero: Self.zero, orientation: .portraitUpsideDown)
        let upright = FoldGlassModel.parameters(attitude: rolled, zero: Self.zero, orientation: .portrait)
        #expect(upsideDown.angle == -upright.angle)
    }

    @Test("REQ-FG-004 a roll across the ±180° seam is measured the short way round")
    func angleWraps() {
        let zero = DeviceAttitude(roll: 3.1, pitch: 0)
        let across = DeviceAttitude(roll: -3.1, pitch: 0)
        let parameters = FoldGlassModel.parameters(attitude: across, zero: zero, orientation: .portrait)
        #expect(abs(parameters.angle) < 0.1)
    }

    @Test("REQ-FG-003 the tracker calibrates on its first sample and ends flat when motion stops")
    func trackerEndsFlat() async {
        let source = FixedMotionSource(samples: [Self.zero, Self.tilted(roll: 0.2)])
        let tracker = FoldGlassTracker(source: source)
        var seen: [FoldGlassParameters] = []
        await tracker.track(orientation: { .portrait }, onUpdate: { seen.append($0) })
        #expect(seen.first == .flat)
        #expect(seen.dropFirst().first.map { $0.angle < 0 } == true)
        #expect(tracker.parameters == .flat)
    }

    @Test("REQ-FG-003 a device without motion never leaves the flat interface")
    func trackerWithoutMotionStaysFlat() async {
        let tracker = FoldGlassTracker(source: FixedMotionSource(samples: []))
        var seen: [FoldGlassParameters] = []
        await tracker.track(orientation: { .portrait }, onUpdate: { seen.append($0) })
        #expect(seen.isEmpty)
        #expect(tracker.parameters == .flat)
    }

    @Test("REQ-FG-004 a fixed tilt holds Home turned for snapshots and scenarios, and ends flat")
    func fixedTiltHolds() async {
        #expect(FixedMotionSource.tilted(degrees: 0).samples.isEmpty)
        let tracker = FoldGlassTracker(source: FixedMotionSource.tilted(degrees: 12))
        let tracking = Task { await tracker.track(orientation: { .portrait }) }
        var spins = 0
        while tracker.parameters == .flat, spins < 1000 {
            await Task.yield()
            spins += 1
        }
        #expect(abs(tracker.parameters.angle + 12 * .pi / 180) < 1e-9)
        tracking.cancel()
        await tracking.value
        #expect(tracker.parameters == .flat)
    }
}
