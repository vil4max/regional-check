import CoreMotion
import Foundation
import simd

/// Where the fold glass gets device attitude. One consumer at a time: Home's effect.
protocol MotionProviding: Sendable {
    /// Attitude samples for as long as the stream is iterated; it finishes at once when the
    /// device reports no motion (the simulator), which leaves Home flat (REQ-FG-003).
    func attitudes() -> AsyncStream<DeviceAttitude>
}

/// Core Motion device motion at 30 Hz. `CMMotionManager` needs no usage description: Apple's
/// `NSMotionUsageDescription` page lists motion-activity, pedometer and sensor-recorder APIs,
/// not device motion. Updates stop as soon as the consumer stops iterating.
final class CoreMotionSource: MotionProviding {
    private let manager = MotionManagerBox()

    func attitudes() -> AsyncStream<DeviceAttitude> {
        let manager = manager
        // Only the newest attitude matters; a slow frame never builds a queue of old ones.
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            guard manager.value.isDeviceMotionAvailable else {
                continuation.finish()
                return
            }
            manager.generation += 1
            let generation = manager.generation
            manager.value.deviceMotionUpdateInterval = 1.0 / 30.0
            manager.value.startDeviceMotionUpdates(to: .main) { motion, _ in
                guard let motion else { return }
                let quaternion = motion.attitude.quaternion
                continuation.yield(DeviceAttitude(
                    quaternion: simd_quatd(ix: quaternion.x, iy: quaternion.y, iz: quaternion.z, r: quaternion.w)
                ))
            }
            continuation.onTermination = { _ in
                // A newer stream may have started before this hop runs; leave it running.
                Task { @MainActor in
                    if manager.generation == generation {
                        manager.value.stopDeviceMotionUpdates()
                    }
                }
            }
        }
    }
}

/// `CMMotionManager` is not `Sendable`. The box only carries it into the stream's termination
/// handler, which hops back to the main actor; Home starts the stream on the main actor too, so
/// the manager is only ever touched from the main thread.
private final class MotionManagerBox: @unchecked Sendable {
    let value = CMMotionManager()
    /// Counts started streams, so a late stop from an old one cannot end a newer one.
    var generation = 0
}

#if DEBUG
    /// Replays fixed samples for tests, previews and scenarios. With `finishes` false the stream
    /// stays open after the last sample, so a snapshot keeps the tilt it was given.
    struct FixedMotionSource: MotionProviding {
        let samples: [DeviceAttitude]
        var finishes = true

        /// Calibrates at rest, then holds a roll of `degrees` for as long as Home is shown; zero
        /// degrees is the flat interface, with no motion at all.
        static func tilted(degrees: Double) -> FixedMotionSource {
            guard degrees != 0 else { return FixedMotionSource(samples: []) }
            let tilted = DeviceAttitude.rotation(aroundY: degrees * .pi / 180)
            return FixedMotionSource(samples: [.identity, tilted], finishes: false)
        }

        func attitudes() -> AsyncStream<DeviceAttitude> {
            AsyncStream { continuation in
                for sample in samples {
                    continuation.yield(sample)
                }
                if finishes {
                    continuation.finish()
                }
            }
        }
    }
#endif
