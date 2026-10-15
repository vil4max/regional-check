import SwiftUI

/// The root cold-start overlay (RD-15B; Part B). Plays once per process launch, above
/// `MainTabView`, then removes itself — never on foreground resume (`RegionalCheckApp` only
/// creates one of these per launch, guarded by its own `@State`, not by anything in this view).
///
/// Plays `ColdStartSequence`'s pure schedule with real time via `Task.sleep`, and renders
/// `ColdStartHeroView` for the current phase. Ignores touches and is hidden from accessibility
/// while active (REQ-LAUNCH-005); `onFinished` lets the caller move VoiceOver focus to the real
/// hero once the overlay is gone.
struct ColdStartOverlay: View {
    let hasCachedStatus: Bool
    /// `StatusController.awaitStatusSettled()` — suspends until a refresh settles. Only ever
    /// called via `ColdStartSettling.awaitIfNeeded` when `hasCachedStatus` is false: the closure
    /// itself also treats a concurrently running refresh as "not yet settled" even with a cached
    /// snapshot present, which is correct for its other callers but wrong for a cold start that
    /// already has an answer. Closures, not `any RegionStatusSource`, because this also needs the
    /// *resolved accent*, which that protocol doesn't expose.
    let awaitStatusSettled: () async -> Void
    let currentAccent: () -> Theme.RedesignStatusAccent?
    let statusKnownAt: () -> ContinuousClock.Instant?
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: ColdStartPhase = .launch
    @State private var sweepAngle: Angle = .zero

    var body: some View {
        ZStack {
            Theme.RedesignColors.background
            ColdStartHeroView(phase: phase, reduceMotion: reduceMotion, sweepAngle: sweepAngle)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await run() }
    }

    private func run() async {
        guard
            let initialPhase = ColdStartSequence.initialPhase(
                hasCachedStatus: hasCachedStatus,
                reduceMotion: reduceMotion
            )
        else {
            finish()
            return
        }
        phase = initialPhase

        // REQ-LAUNCH-002: bounded by `awaitStatusSettled`'s own timeout; a cached status never
        // reaches this point (see `ColdStartSettling`).
        await ColdStartSettling.awaitIfNeeded(
            hasCachedStatus: hasCachedStatus,
            whileWaiting: {
                if initialPhase == .checking {
                    await sweepUntilKnown()
                }
            },
            awaitStatusSettled: awaitStatusSettled
        )
        guard !Task.isCancelled else { return }
        guard let accent = currentAccent() else {
            // Genuinely unresolved even after settling (e.g. `.idle`) — hand off without a
            // status flourish rather than hang; the real Status screen shows its own checking
            // state from here.
            finish()
            return
        }

        #if DEBUG
            ColdStartTrace.record("transition-start")
        #endif
        await playKnownSequence(accent: accent)
        guard !Task.isCancelled else { return }
        finish()
    }

    /// Settling owns the timeout and cancels this animation as soon as status resolves.
    private func sweepUntilKnown() async {
        while currentAccent() == nil, !Task.isCancelled {
            withAnimation(.linear(duration: 0.3)) {
                sweepAngle += .degrees(90)
            }
            try? await Task.sleep(for: .milliseconds(300))
            if currentAccent() != nil {
                return
            }
        }
    }

    /// Plays `ColdStartSequence.knownSchedule`, timed from the moment status became known.
    private func playKnownSequence(accent: Theme.RedesignStatusAccent) async {
        let start = statusKnownAt() ?? ContinuousClock.now
        let schedule = ColdStartSequence.knownSchedule(
            accent: accent,
            elapsedAtStart: ContinuousClock.now - start,
            reduceMotion: reduceMotion
        )
        guard !schedule.steps.isEmpty else { return }
        for step in schedule.steps {
            await sleep(until: step.offset, from: start)
            guard !Task.isCancelled else { return }
            withAnimation(animation(for: step.transition)) {
                phase = step.phase
            }
        }
        await sleep(until: schedule.handoffAt, from: start)
    }

    private func sleep(until offset: Duration, from start: ContinuousClock.Instant) async {
        let remaining = offset - (ContinuousClock.now - start)
        if remaining > .zero {
            try? await Task.sleep(for: remaining)
        }
    }

    private func animation(for transition: ColdStartTransition) -> Animation {
        switch transition {
        case .crossFade: .easeInOut(duration: ColdStartTiming.reduceMotionCrossFade.seconds)
        case .spring: .spring(duration: 0.35, bounce: 0.3)
        }
    }

    private func finish() {
        onFinished()
        #if DEBUG
            ColdStartTrace.record("overlay-removal-requested")
        #endif
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
