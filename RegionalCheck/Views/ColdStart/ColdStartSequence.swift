import Foundation

/// The cold-start overlay's phase (RD-15B; `docs/tasks/rd-15-app-icon-launch-cold-start.md` Part
/// B, `docs/requirements/launch-and-cold-start.md`). `accent` is `Theme.RedesignStatusAccent` —
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
    /// The overlay is gone; the real hero sits in the same place.
    case ready
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
}

/// Pure mapping from "what do we know, and how long ago did we learn it" to a `ColdStartPhase`.
/// No timers, no clock reads: the owning view drives real time (`Task.sleep`/`TimelineView`) and
/// calls `phase(...)` with the elapsed `Duration`, which is what makes this exhaustively testable
/// with `Swift Testing` instead of sleeping in tests.
enum ColdStartSequence {
    /// REQ-LAUNCH-003, 005: `true` when the checking sweep should never play — a cached status
    /// (fresh or stale) is already known synchronously at launch (`StatusController.init()` loads
    /// it before the first frame), so there is nothing to sweep for; Reduce Motion never sweeps
    /// either, regardless of cache. A *fresh* cache is the case REQ-LAUNCH-003 names, but a stale
    /// one is equally "already known" — REQ-LAUNCH-004 only constrains which *color* phase 2 uses
    /// once reached, not whether phase 1 is skipped, so treating any cached status the same way
    /// here does not contradict it.
    static func skipsCheckingSweep(hasCachedStatus: Bool, reduceMotion: Bool) -> Bool {
        hasCachedStatus || reduceMotion
    }

    /// `accent` is `nil` while status is genuinely unknown (no cache, network not yet resolved).
    /// `elapsedSinceKnown` is measured from the moment `accent` first became non-nil and is
    /// ignored while it's still `nil`.
    static func phase(
        accent: Theme.RedesignStatusAccent?,
        elapsedSinceKnown: Duration,
        hasCachedStatus: Bool,
        reduceMotion: Bool
    ) -> ColdStartPhase {
        guard let accent else {
            return skipsCheckingSweep(hasCachedStatus: hasCachedStatus, reduceMotion: reduceMotion)
                ? .launch
                : .checking
        }
        if reduceMotion {
            return elapsedSinceKnown < ColdStartTiming.reduceMotionCrossFade
                ? .statusKnown(accent: accent)
                : .ready
        }
        if elapsedSinceKnown < ColdStartTiming.symbolDelay {
            return .statusKnown(accent: accent)
        }
        if elapsedSinceKnown < ColdStartTiming.readyDelay {
            return .symbol(accent: accent)
        }
        return .ready
    }
}
