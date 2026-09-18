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
    /// `StatusController.awaitStatusSettled()` — suspends until a refresh settles, or returns
    /// immediately when a snapshot already exists. Closures, not `any RegionStatusSource`,
    /// because this also needs the *resolved accent*, which that protocol doesn't expose.
    let awaitStatusSettled: () async -> Void
    let currentAccent: () -> Theme.RedesignStatusAccent?
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: ColdStartPhase = .launch
    @State private var sweepAngle: Angle = .zero
    @State private var isFinished = false

    var body: some View {
        if !isFinished {
            ZStack {
                Theme.RedesignColors.background
                ColdStartHeroView(phase: phase, reduceMotion: reduceMotion, sweepAngle: sweepAngle)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task { await run() }
        }
    }

    private func run() async {
        // REQ-LAUNCH-003: a cached status (fresh or stale) is already known synchronously —
        // `StatusController.init()` loads it before this view ever appears — so there is nothing
        // to sweep for. Reduce Motion never sweeps either (REQ-LAUNCH-005).
        let skipsSweep = ColdStartSequence.skipsCheckingSweep(
            hasCachedStatus: hasCachedStatus,
            reduceMotion: reduceMotion
        )
        phase = skipsSweep ? .launch : .checking

        if !skipsSweep {
            await sweepUntilKnown()
        }

        // REQ-LAUNCH-002: never wait longer than the Status screen itself would — bounded by
        // `awaitStatusSettled`'s own timeout.
        await awaitStatusSettled()
        guard let accent = currentAccent() else {
            // Genuinely unresolved even after settling (e.g. `.idle`) — hand off without a
            // status flourish rather than hang; the real Status screen shows its own checking
            // state from here.
            finish()
            return
        }

        await playKnownSequence(accent: accent)
        finish()
    }

    /// Loops the sweep animation while status is still unknown (rule 3: never block the UI
    /// longer than the Status screen's own timeout — `awaitStatusSettled` bounds this loop from
    /// the caller in `run()`, this just animates while it waits).
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
        let start = ContinuousClock.now
        if reduceMotion {
            withAnimation(.easeInOut(duration: ColdStartTiming.reduceMotionCrossFade.seconds)) {
                phase = .statusKnown(accent: accent)
            }
            try? await Task.sleep(for: ColdStartTiming.reduceMotionCrossFade)
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .statusKnown(accent: accent)
        }
        try? await Task.sleep(for: ColdStartTiming.symbolDelay)
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            phase = .symbol(accent: accent)
        }
        let elapsed = ContinuousClock.now - start
        let remaining = ColdStartTiming.readyDelay - elapsed
        if remaining > .zero {
            try? await Task.sleep(for: remaining)
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isFinished = true
        }
        onFinished()
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
