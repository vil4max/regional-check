@testable import RegionalCheck
import Testing

/// `docs/requirements/launch-and-cold-start.md`, through the schedule `ColdStartOverlay` plays
/// (`ColdStartSequence.initialPhase` and `knownSchedule`). REQ-LAUNCH-005's touch-ignoring,
/// accessibility-hiding and VoiceOver-focus-handoff clauses are view-modifier concerns
/// (`ColdStartOverlay`), not schedule outputs — this repo's UI is not automated
/// (`testing-strategy.md`), so those three clauses are verified by code review, a deliberate gap
/// rather than an accident.
struct ColdStartSequenceTests {
    private static let accents = Theme.RedesignStatusAccent.allCases

    @Test("REQ-LAUNCH-002 startup work consumes the known-status budget")
    func handoffBudgetIncludesTimeBeforeOverlayStarts() {
        let late = ColdStartSequence.knownSchedule(
            accent: .clear,
            elapsedAtStart: .milliseconds(180),
            reduceMotion: false
        )
        #expect(late.handoffAt - .milliseconds(180) == .milliseconds(170))
        #expect(!late.steps.isEmpty)

        let tooLate = ColdStartSequence.knownSchedule(
            accent: .clear,
            elapsedAtStart: .milliseconds(400),
            reduceMotion: false
        )
        #expect(tooLate.steps.isEmpty)
        let reduceMotionTooLate = ColdStartSequence.knownSchedule(
            accent: .clear,
            elapsedAtStart: .milliseconds(200),
            reduceMotion: true
        )
        #expect(reduceMotionTooLate.steps.isEmpty)
    }

    @Test("REQ-LAUNCH-001 before status is known the overlay shows only the neutral mark")
    func neverShowsAStatusColorBeforeStatusIsKnown() {
        for reduceMotion in [true, false] {
            let phase = ColdStartSequence.initialPhase(hasCachedStatus: false, reduceMotion: reduceMotion)
            #expect(phase == .launch || phase == .checking)
        }
    }

    @Test("REQ-LAUNCH-002 the overlay hands off at most 400 ms after status is known")
    func readyWithinTheApprovedCeiling() {
        for reduceMotion in [true, false] {
            for accent in Self.accents {
                let schedule = ColdStartSequence.knownSchedule(
                    accent: accent,
                    elapsedAtStart: .zero,
                    reduceMotion: reduceMotion
                )
                #expect(schedule.handoffAt <= .milliseconds(400))
                #expect(schedule.steps.allSatisfy { $0.offset < schedule.handoffAt })
                #expect(schedule.steps.first?.phase == .statusKnown(accent: accent))
                #expect(schedule.steps.first?.offset == .zero)
            }
        }
        let full = ColdStartSequence.knownSchedule(accent: .clear, elapsedAtStart: .zero, reduceMotion: false)
        #expect(full.steps.map(\.phase) == [.statusKnown(accent: .clear), .symbol(accent: .clear)])
        #expect(full.steps.map(\.offset) == [.zero, ColdStartTiming.symbolDelay])
        #expect(ColdStartTiming.readyDelay <= .milliseconds(400))
    }

    @Test("REQ-LAUNCH-003 a cached status at launch skips the checking sweep")
    func cachedStatusSkipsTheSweep() {
        for reduceMotion in [true, false] {
            // No overlay phase at all: the overlay hands off to the status it already has.
            #expect(ColdStartSequence.initialPhase(hasCachedStatus: true, reduceMotion: reduceMotion) == nil)
        }
        #expect(ColdStartSequence.initialPhase(hasCachedStatus: false, reduceMotion: false) == .checking)
    }

    @Test("REQ-LAUNCH-004 a stale status uses the stale accent and the clock, never clear")
    func staleIsNeverGreen() {
        let accent = Theme.RedesignStatusAccent(phase: .quiet, isStale: true)
        #expect(accent == .stale)
        #expect(accent.symbolName == "clock.fill")
        let schedule = ColdStartSequence.knownSchedule(accent: accent, elapsedAtStart: .zero, reduceMotion: false)
        #expect(schedule.steps.map(\.phase) == [.statusKnown(accent: .stale), .symbol(accent: .stale)])
    }

    @Test("REQ-LAUNCH-005 Reduce Motion skips the sweep and the spring, cross-fading in 200 ms")
    func reduceMotionCrossFadesOnly() {
        #expect(ColdStartSequence.initialPhase(hasCachedStatus: false, reduceMotion: true) == .launch)
        let schedule = ColdStartSequence.knownSchedule(accent: .alert, elapsedAtStart: .zero, reduceMotion: true)
        #expect(schedule.steps == [.init(offset: .zero, phase: .statusKnown(accent: .alert), transition: .crossFade)])
        #expect(schedule.handoffAt <= ColdStartTiming.reduceMotionCrossFade)
        #expect(ColdStartTiming.reduceMotionCrossFade == .milliseconds(200))
    }
}
