import Foundation
import os

/// The cold-start overlay's phase (RD-15B, `docs/requirements/launch-and-cold-start.md`).
/// `accent` is `Theme.RedesignStatusAccent` —
/// never a bare `Color` — so a phase can't accidentally carry a status-bearing color before
/// status is known (REQ-LAUNCH-001).
enum ColdStartPhase: Equatable, Sendable {
    /// The launch mark exactly as the launch screen: neutral dot, no status color.
    case launch
    /// Ticks sweep clockwise from 12 o'clock; status not known yet.
    case checking
    /// Ring cross-fades to `accent`; the dot fades out while the disc springs in.
    case statusKnown(accent: Theme.RedesignStatusAccent)
    /// The status symbol has sprung in; title/region/cards fade up underneath.
    case symbol(accent: Theme.RedesignStatusAccent)
}

/// How the overlay animates into a step's phase.
enum ColdStartTransition: Equatable, Sendable {
    /// An ease-in-out cross-fade of `ColdStartTiming.reduceMotionCrossFade`.
    case crossFade
    /// The symbol's spring; never under Reduce Motion (REQ-LAUNCH-005).
    case spring
}

/// What the overlay plays once status is known: each step's phase at its offset from that moment,
/// and the offset at which the overlay hands off to the real Status screen.
struct ColdStartSchedule: Equatable, Sendable {
    struct Step: Equatable, Sendable {
        let offset: Duration
        let phase: ColdStartPhase
        let transition: ColdStartTransition
    }

    let steps: [Step]
    let handoffAt: Duration
}

/// Fixed durations from `geometry-and-tokens.md` §4 and the Part B phase table — the only clock
/// numbers this feature uses (rule 6: "no second set of numbers").
enum ColdStartTiming {
    /// When phase 3 (symbol) starts, measured from status becoming known — the cutover point
    /// this type switches `.statusKnown` to `.symbol` at. Phase 2's own cross-fade/spring keeps
    /// animating past this point; the phase case only tracks which layer just started, not when
    /// each animation settles.
    static let symbolDelay: Duration = .milliseconds(150)
    /// How long phase 3 is shown once it starts.
    static let symbolDuration: Duration = .milliseconds(250)
    /// Total time added after status is known (rule 5): `symbolDelay + symbolDuration`, computed
    /// rather than restated so the 400 ms ceiling can't drift from the two numbers it's made of.
    static let readyDelay: Duration = symbolDelay + symbolDuration
    /// Reduce Motion's only animation: a flat cross-fade, no sweep, no spring (REQ-LAUNCH-005).
    static let reduceMotionCrossFade: Duration = .milliseconds(200)

    /// Leave time for the state change to reach the display; start-up work consumes the same budget.
    static let displayReserve: Duration = .milliseconds(50)
}

/// The schedule `ColdStartOverlay` plays, as pure functions of what is known. No timers and no
/// clock reads: the overlay sleeps until each step's offset, so the tests cover what it runs.
enum ColdStartSequence {
    /// The phase the overlay opens with, or `nil` when a cached status (fresh or stale) is
    /// already known at launch: `StatusController.init()` loads it before the first frame, so the
    /// overlay hands off at once rather than delay a status the app already has (REQ-LAUNCH-003).
    /// Without a cache it is the neutral mark (REQ-LAUNCH-001), sweeping unless Reduce Motion is
    /// on (REQ-LAUNCH-005).
    static func initialPhase(hasCachedStatus: Bool, reduceMotion: Bool) -> ColdStartPhase? {
        guard !hasCachedStatus else { return nil }
        return reduceMotion ? .launch : .checking
    }

    /// The steps after status becomes known, `elapsedAtStart` after it did. Startup work spends
    /// the same budget, so once the hand-off point has passed nothing plays (REQ-LAUNCH-002).
    static func knownSchedule(
        accent: Theme.RedesignStatusAccent,
        elapsedAtStart: Duration,
        reduceMotion: Bool
    ) -> ColdStartSchedule {
        let ceiling = reduceMotion ? ColdStartTiming.reduceMotionCrossFade : ColdStartTiming.readyDelay
        let handoffAt = ceiling - ColdStartTiming.displayReserve
        guard elapsedAtStart < handoffAt else {
            return ColdStartSchedule(steps: [], handoffAt: handoffAt)
        }
        let statusKnown = ColdStartSchedule.Step(
            offset: .zero,
            phase: .statusKnown(accent: accent),
            transition: .crossFade
        )
        if reduceMotion {
            return ColdStartSchedule(steps: [statusKnown], handoffAt: handoffAt)
        }
        let symbol = ColdStartSchedule.Step(
            offset: ColdStartTiming.symbolDelay,
            phase: .symbol(accent: accent),
            transition: .spring
        )
        return ColdStartSchedule(steps: [statusKnown, symbol], handoffAt: handoffAt)
    }
}

#if DEBUG
    enum ColdStartTrace {
        private static let logger = Logger(subsystem: "vil4max.RegionalCheck", category: "ColdStartMeasurement")

        static func record(_ event: String) {
            guard ProcessInfo.processInfo.arguments.contains("-MeasureColdStart") else { return }
            logger.notice("\(event, privacy: .public) uptime=\(ProcessInfo.processInfo.systemUptime, privacy: .public)")
        }
    }
#endif
