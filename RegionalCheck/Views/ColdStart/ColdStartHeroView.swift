import SwiftUI

/// Draws the launch mark / cold-start hero for a given `ColdStartPhase`. `.launch`/`.checking` (no
/// accent known yet) draw their own neutral dot and sweep ring — there's no equivalent state in
/// `StatusHeroCard`, which never renders before an accent exists. `.statusKnown`/`.symbol` (accent
/// known) hand off to `StatusHeroGraphic`, the same view `StatusHeroCard` uses, so the hand-off
/// frame is pixel-identical to the real hero by construction rather than by matching numbers by
/// hand — see `StatusHeroGraphic`'s doc comment for why that used to drift.
/// Deliberately does not use `.glassEffect()` or any system material: those follow the device's
/// light/dark appearance regardless of this app's dark-only tokens (a finding from the RD-7
/// bottom-bar report), and setting `.preferredColorScheme` here would collide with the fix already
/// assigned to that card.
struct ColdStartHeroView: View {
    let phase: ColdStartPhase
    let reduceMotion: Bool

    /// Drives the phase-1 sweep's rotation; owned by the overlay, not this view, so previews and
    /// snapshot tests of a single phase stay static.
    var sweepAngle: Angle = .zero

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAX5: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var ringDiameter: CGFloat {
        isAX5 ? Theme.RedesignHeroSizes.ax5RingDiameter : Theme.RedesignHeroSizes.ringDiameter
    }

    private var ringRadius: CGFloat {
        isAX5 ? Theme.RedesignHeroSizes.ax5RingRadius : Theme.RedesignHeroSizes.ringRadius
    }

    private var tickLength: CGFloat {
        isAX5 ? Theme.RedesignHeroSizes.ax5TickLength : Theme.RedesignHeroSizes.tickLength
    }

    var body: some View {
        Group {
            switch phase {
            case .launch, .checking:
                ZStack {
                    ring
                    neutralDot
                }
                .frame(width: ringDiameter, height: ringDiameter)
            case let .statusKnown(accent), let .symbol(accent):
                // One `StatusHeroGraphic` instance across both cases, not two — only `showsSymbol`
                // changes, so the disc keeps its identity (no re-grow) while the symbol plays its
                // own appear transition, matching how the equivalent two-step reveal worked before
                // this used `StatusHeroGraphic`. Two separate `case` branches each constructing
                // their own instance would let SwiftUI treat the .statusKnown → .symbol move as a
                // full swap instead of a parameter change.
                StatusHeroGraphic(
                    accent: accent,
                    symbolName: symbolName(for: accent),
                    showsSymbol: isSymbolPhase,
                    isColdStartHandoffCopy: true
                )
                .transition(.scale(scale: 0.204).combined(with: .opacity))
            case .ready:
                EmptyView()
            }
        }
        .accessibilityHidden(true)
    }

    private var isSymbolPhase: Bool {
        if case .symbol = phase {
            return true
        }
        return false
    }

    // MARK: - Ring (pre-known phases only — `StatusHeroGraphic` draws the known-accent ring)

    private var ring: some View {
        ForEach(0 ..< Theme.RedesignHeroSizes.tickCount, id: \.self) { index in
            tick(at: index)
        }
    }

    private func tick(at index: Int) -> some View {
        let degrees = Double(index) * (360.0 / Double(Theme.RedesignHeroSizes.tickCount))
        return Capsule()
            .fill(tickColor(at: index))
            .frame(width: Theme.RedesignHeroSizes.tickWidth, height: tickLength)
            .offset(y: -ringRadius)
            .rotationEffect(.degrees(degrees))
    }

    /// REQ-LAUNCH-001: with no accent, ticks are `ringIdle` only — never a status color. The
    /// sweep (phase 1) brightens ticks near 12 o'clock, moving clockwise, using `ringSweep`.
    /// Only reachable for `.launch`/`.checking` — `StatusHeroGraphic` owns the known-accent ring.
    private func tickColor(at index: Int) -> Color {
        switch phase {
        case .checking:
            let degrees = Double(index) * (360.0 / Double(Theme.RedesignHeroSizes.tickCount))
            let distance = angularDistance(degrees, sweepAngle.degrees)
            // Brightest at the sweep's leading edge, fading back to idle within a ~90° tail.
            let brightness = max(0, 1 - distance / 90)
            return Theme.RedesignColors.ringIdleBase.opacity(0.12 + 0.58 * brightness) // up to ringSweep-ish
        case .launch, .statusKnown, .symbol, .ready:
            return Theme.RedesignColors.ringIdleBase
        }
    }

    private func angularDistance(_ lhs: Double, _ rhs: Double) -> Double {
        let diff = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    /// The neutral 22 pt dot (0.204 of the 108 pt disc) — no glow, no disc fill yet
    /// (`.launch`/`.checking` only; status isn't known so no accent color is drawn).
    private var neutralDot: some View {
        Circle()
            .fill(Theme.RedesignColors.textBody)
            .frame(
                width: Theme.RedesignHeroSizes.discDiameter * 0.204,
                height: Theme.RedesignHeroSizes.discDiameter * 0.204
            )
    }

    /// REQ-LAUNCH-004: stale is the clock symbol, matching the Status screen, never the clear
    /// (checkmark) glyph.
    private func symbolName(for accent: Theme.RedesignStatusAccent) -> String {
        switch accent {
        case .clear: "checkmark.circle.fill"
        case .alert: "exclamationmark.circle.fill"
        case .stale: "clock.fill"
        case .checking: "arrow.triangle.2.circlepath"
        // Same glyph `StatusState.symbolName` already returns for `.error`/`.regionUnavailable`
        // (drivecheck-product: reuse it, don't invent a new one).
        case .unavailable: "questionmark.circle.fill"
        }
    }
}

#if DEBUG
    #Preview("Cold start — launch") {
        ColdStartHeroView(phase: .launch, reduceMotion: false)
            .padding(60)
            .background(Theme.RedesignColors.background)
    }

    #Preview("Cold start — checking") {
        ColdStartHeroView(phase: .checking, reduceMotion: false, sweepAngle: .degrees(90))
            .padding(60)
            .background(Theme.RedesignColors.background)
    }

    #Preview("Cold start — status known (clear)") {
        ColdStartHeroView(phase: .statusKnown(accent: .clear), reduceMotion: false)
            .padding(60)
            .background(Theme.RedesignColors.background)
    }

    #Preview("Cold start — symbol (alert)") {
        ColdStartHeroView(phase: .symbol(accent: .alert), reduceMotion: false)
            .padding(60)
            .background(Theme.RedesignColors.background)
    }

    #Preview("Cold start — symbol (stale)") {
        ColdStartHeroView(phase: .symbol(accent: .stale), reduceMotion: false)
            .padding(60)
            .background(Theme.RedesignColors.background)
    }
#endif
