import SwiftUI

/// The root cold-start overlay (RD-15B; Part B). Plays once per process launch, above
/// `MainTabView`, then removes itself — never on foreground resume (`RegionalCheckApp` only
/// creates one of these per launch, guarded by its own `@State`, not by anything in this view).
///
/// Drives `ColdStartSequence`'s pure phase mapping with real time via `Task.sleep`, and renders
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
        if hasCachedStatus {
            finish()
            return
        }
        // REQ-LAUNCH-003: a cached status (fresh or stale) is already known synchronously —
        // `StatusController.init()` loads it before this view ever appears — so there is nothing
        // to sweep for. Reduce Motion never sweeps either (REQ-LAUNCH-005).
        let skipsSweep = ColdStartSequence.skipsCheckingSweep(
            hasCachedStatus: hasCachedStatus,
            reduceMotion: reduceMotion
        )
        phase = skipsSweep ? .launch : .checking

        // REQ-LAUNCH-002/003: bounded by `awaitStatusSettled`'s own timeout when there is no
        // cache; never waits at all when there is one, however a concurrently started refresh's
        // `isLoading` happens to read — see `ColdStartSettling`.
        await ColdStartSettling.awaitIfNeeded(
            hasCachedStatus: hasCachedStatus,
            whileWaiting: {
                if !skipsSweep {
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

    private func playKnownSequence(accent: Theme.RedesignStatusAccent) async {
        let start = statusKnownAt() ?? ContinuousClock.now
        let elapsedAtStart = ContinuousClock.now - start
        guard ColdStartTiming.remainingBeforeHandoff(elapsed: elapsedAtStart, reduceMotion: reduceMotion) > .zero else {
            return
        }
        if reduceMotion {
            withAnimation(.easeInOut(duration: ColdStartTiming.reduceMotionCrossFade.seconds)) {
                phase = .statusKnown(accent: accent)
            }
            try? await Task.sleep(for: ColdStartTiming.remainingBeforeHandoff(
                elapsed: ContinuousClock.now - start, reduceMotion: true
            ))
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .statusKnown(accent: accent)
        }
        let untilSymbol = ColdStartTiming.symbolDelay - (ContinuousClock.now - start)
        if untilSymbol > .zero {
            try? await Task.sleep(for: untilSymbol)
        }
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            phase = .symbol(accent: accent)
        }
        let elapsed = ContinuousClock.now - start
        let remaining = ColdStartTiming.remainingBeforeHandoff(elapsed: elapsed, reduceMotion: false)
        if remaining > .zero {
            try? await Task.sleep(for: remaining)
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
