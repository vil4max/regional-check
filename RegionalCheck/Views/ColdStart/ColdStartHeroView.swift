import SwiftUI

/// Draws the launch mark / cold-start hero for a given `ColdStartPhase` — the same 156 pt ring +
/// 108 pt disc + 54 pt symbol geometry as `Theme.RedesignHeroSizes` (RD-5's numbers; RD-5 itself
/// isn't landed yet, so this reads the shared token file's constants, not RD-5's view code —
/// rule 6, "no second set of numbers"). Deliberately does not use `.glassEffect()` or any system
/// material: those follow the device's light/dark appearance regardless of this app's dark-only
/// tokens (a finding from the RD-7 bottom-bar report), and setting `.preferredColorScheme` here
/// would collide with the fix already assigned to that card.
struct ColdStartHeroView: View {
    let phase: ColdStartPhase
    let reduceMotion: Bool

    /// Drives the phase-1 sweep's rotation; owned by the overlay, not this view, so previews and
    /// snapshot tests of a single phase stay static.
    var sweepAngle: Angle = .zero

    var body: some View {
        ZStack {
            ring
            discAndSymbol
        }
        .frame(width: Theme.RedesignHeroSizes.ringDiameter, height: Theme.RedesignHeroSizes.ringDiameter)
        .accessibilityHidden(true)
    }

    // MARK: - Ring

    private var ring: some View {
        ForEach(0 ..< Theme.RedesignHeroSizes.tickCount, id: \.self) { index in
            tick(at: index)
        }
    }

    private func tick(at index: Int) -> some View {
        let degrees = Double(index) * (360.0 / Double(Theme.RedesignHeroSizes.tickCount))
        return Capsule()
            .fill(tickColor(at: index))
            .frame(width: Theme.RedesignHeroSizes.tickWidth, height: Theme.RedesignHeroSizes.tickLength)
            .offset(y: -Theme.RedesignHeroSizes.ringRadius)
            .rotationEffect(.degrees(degrees))
    }

    /// REQ-LAUNCH-001: with no accent, ticks are `ringIdle` only — never a status color. The
    /// sweep (phase 1) brightens ticks near 12 o'clock, moving clockwise, using `ringSweep`;
    /// once an accent is known, every tick is a flat `ringStatus` (accent 38%, geometry-and-
    /// tokens.md §1) with no per-tick variation.
    private func tickColor(at index: Int) -> Color {
        switch phase {
        case .launch:
            return Theme.RedesignColors.ringIdleBase
        case .checking:
            let degrees = Double(index) * (360.0 / Double(Theme.RedesignHeroSizes.tickCount))
            let distance = angularDistance(degrees, sweepAngle.degrees)
            // Brightest at the sweep's leading edge, fading back to idle within a ~90° tail.
            let brightness = max(0, 1 - distance / 90)
            return Theme.RedesignColors.ringIdleBase.opacity(0.12 + 0.58 * brightness) // up to ringSweep-ish
        case let .statusKnown(accent), let .symbol(accent):
            return Theme.RedesignColors.statusAccent(for: accent).opacity(Theme.RedesignColors.ringStatusOpacity)
        case .ready:
            return Color.clear
        }
    }

    private func angularDistance(_ lhs: Double, _ rhs: Double) -> Double {
        let diff = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    // MARK: - Disc, dot, symbol

    @ViewBuilder
    private var discAndSymbol: some View {
        switch phase {
        case .launch, .checking:
            // The neutral 22 pt dot (0.204 of the 108 pt disc) — no glow, no disc fill yet.
            Circle()
                .fill(Theme.RedesignColors.textBody)
                .frame(
                    width: Theme.RedesignHeroSizes.discDiameter * 0.204,
                    height: Theme.RedesignHeroSizes.discDiameter * 0.204
                )
        case let .statusKnown(accent):
            disc(for: accent)
                .transition(.scale(scale: 0.204).combined(with: .opacity))
        case let .symbol(accent):
            disc(for: accent)
            symbol(for: accent)
                .transition(.scale.combined(with: .opacity))
        case .ready:
            EmptyView()
        }
    }

    private func disc(for accent: Theme.RedesignStatusAccent) -> some View {
        let color = Theme.RedesignColors.statusAccent(for: accent)
        let tints = Theme.RedesignColors.tints(for: color)
        return Circle()
            .fill(tints.soft)
            .overlay(Circle().strokeBorder(tints.edge, lineWidth: 0.7))
            .frame(width: Theme.RedesignHeroSizes.discDiameter, height: Theme.RedesignHeroSizes.discDiameter)
    }

    private func symbol(for accent: Theme.RedesignStatusAccent) -> some View {
        Image(systemName: symbolName(for: accent))
            .font(.system(size: Theme.RedesignHeroSizes.symbolSize * 0.55, weight: .semibold))
            .foregroundStyle(Theme.RedesignColors.statusAccent(for: accent))
            .frame(width: Theme.RedesignHeroSizes.symbolSize, height: Theme.RedesignHeroSizes.symbolSize)
    }

    /// REQ-LAUNCH-004: stale is the clock symbol, matching the Status screen, never the clear
    /// (checkmark) glyph.
    private func symbolName(for accent: Theme.RedesignStatusAccent) -> String {
        switch accent {
        case .clear: "checkmark.circle.fill"
        case .alert: "exclamationmark.circle.fill"
        case .stale: "clock.fill"
        case .checking: "arrow.triangle.2.circlepath"
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
