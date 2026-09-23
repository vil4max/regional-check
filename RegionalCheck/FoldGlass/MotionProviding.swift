import CoreMotion
import Foundation

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
                continuation.yield(DeviceAttitude(roll: motion.attitude.roll, pitch: motion.attitude.pitch))
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
