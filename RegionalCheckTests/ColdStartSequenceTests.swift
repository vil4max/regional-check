@testable import RegionalCheck
import Testing

/// `docs/requirements/launch-and-cold-start.md`. REQ-LAUNCH-005's touch-ignoring, accessibility-
/// hiding and VoiceOver-focus-handoff clauses are view-modifier concerns (`ColdStartOverlay`),
/// not `ColdStartSequence` outputs — this repo's UI is not automated (`testing-strategy.md`), so
/// those three clauses are verified by code review and the screen recordings in the report, a
/// deliberate gap rather than an accident.
struct ColdStartSequenceTests {
    @Test("REQ-LAUNCH-001 no accent means launch or checking, never a status-colored phase")
    func neverShowsAStatusColorBeforeStatusIsKnown() {
        for hasCachedStatus in [true, false] {
            for reduceMotion in [true, false] {
                for elapsed in [Duration.zero, .milliseconds(50), .milliseconds(500)] {
                    let phase = ColdStartSequence.phase(
                        accent: nil,
                        elapsedSinceKnown: elapsed,
                        hasCachedStatus: hasCachedStatus,
                        reduceMotion: reduceMotion
                    )
                    #expect(phase == .launch || phase == .checking)
                }
            }
        }
    }

    @Test("REQ-LAUNCH-002 the overlay is ready at most 400 ms after status is known")
    func readyWithinTheApprovedCeiling() {
        let accent = Theme.RedesignStatusAccent.clear
        #expect(ColdStartSequence.phase(
            accent: accent,
            elapsedSinceKnown: ColdStartTiming.readyDelay,
            hasCachedStatus: false,
            reduceMotion: false
        ) == .ready)
        #expect(ColdStartSequence.phase(
            accent: accent,
            elapsedSinceKnown: ColdStartTiming.readyDelay - .milliseconds(1),
            hasCachedStatus: false,
            reduceMotion: false
        ) != .ready)
        #expect(ColdStartTiming.readyDelay <= .milliseconds(400))
    }

    @Test("REQ-LAUNCH-003 a cached status at launch skips the checking sweep")
    func freshCacheSkipsTheSweep() {
        #expect(ColdStartSequence.skipsCheckingSweep(hasCachedStatus: true, reduceMotion: false))
        #expect(!ColdStartSequence.skipsCheckingSweep(hasCachedStatus: false, reduceMotion: false))
        // With a cache, the app never even calls `phase(accent: nil, …)` — accent is available
        // synchronously at launch — but the moment it's known, phase 2 starts immediately.
        #expect(ColdStartSequence.phase(
            accent: .clear,
            elapsedSinceKnown: .zero,
            hasCachedStatus: true,
            reduceMotion: false
        ) == .statusKnown(accent: .clear))
    }

    @Test("REQ-LAUNCH-004 a stale cached status uses the stale accent, never clear")
    func staleCacheIsNeverGreen() {
        // Mirrors how the app actually derives the accent (Theme.RedesignStatusAccent.init):
        // `isStale` always wins over the phase, so a stale "all clear" snapshot still renders
        // as stale, never clear.
        let accent = Theme.RedesignStatusAccent(phase: .quiet, isStale: true)
        #expect(accent == .stale)
        #expect(ColdStartSequence.phase(
            accent: accent,
            elapsedSinceKnown: .zero,
            hasCachedStatus: true,
            reduceMotion: false
        ) == .statusKnown(accent: .stale))
    }

    @Test("REQ-LAUNCH-005 Reduce Motion skips the sweep and the spring, cross-fading in 200 ms")
    func reduceMotionCrossFadesOnly() {
        #expect(ColdStartSequence.skipsCheckingSweep(hasCachedStatus: false, reduceMotion: true))
        let accent = Theme.RedesignStatusAccent.alert
        // No `.symbol` phase at all under Reduce Motion — a flat cross-fade straight to ready.
        // `Duration` isn't `Strideable`, so stride over whole milliseconds instead.
        let upperBoundMs = wholeMilliseconds(ColdStartTiming.reduceMotionCrossFade + .milliseconds(200))
        for ms in stride(from: 0, through: upperBoundMs, by: 50) {
            let phase = ColdStartSequence.phase(
                accent: accent,
                elapsedSinceKnown: .milliseconds(ms),
                hasCachedStatus: false,
                reduceMotion: true
            )
            #expect(phase == .statusKnown(accent: accent) || phase == .ready)
        }
        #expect(ColdStartSequence.phase(
            accent: accent,
            elapsedSinceKnown: ColdStartTiming.reduceMotionCrossFade,
            hasCachedStatus: false,
            reduceMotion: true
        ) == .ready)
    }
}

/// `Duration` has no `Strideable` conformance, so tests that sweep a range of elapsed times
/// convert to whole milliseconds and stride an `Int` instead.
private func wholeMilliseconds(_ duration: Duration) -> Int {
    let components = duration.components
    return Int(components.seconds * 1000) + Int(components.attoseconds / 1_000_000_000_000_000)
}
