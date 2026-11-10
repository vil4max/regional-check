import SwiftUI

/// The glow and the status symbol, shared by `StatusHeroCard` (the Status tab's live hero) and
/// `ColdStartHeroView`'s known-accent phases (the cold-start overlay's hand-off moment). One view
/// keeps the two from drifting apart.
///
/// UI-simplify AC-1 (owner, 2026-11-10: calm, nothing that reads as scanning for danger): the
/// symbol is still, the filled SF Symbol in the status colour, with no radar, tick ring or
/// repeating effect. The frame keeps the ring's sizes, so REQ-SURF-012's glow and REQ-SURF-013's
/// compact step are unchanged.
struct StatusHeroGraphic: View {
    let accent: Theme.RedesignStatusAccent
    let symbolName: String
    /// `false` for the cold-start overlay's disc-grows-in-before-symbol-springs-in step
    /// (`ColdStartTiming.symbolDelay`); the disc stands in for the symbol until it appears.
    var showsSymbol = true
    /// `true` only for `ColdStartHeroView`'s instance. `StatusHeroCard`'s copy is the one thing on
    /// screen the whole time the hand-off happens, so it's the geometry source
    /// (`matchedGeometryEffect`'s `isSource: true`); the overlay's copy is pulled onto the real
    /// hero's actual frame, never a hardcoded offset.
    var isColdStartHandoffCopy = false
    /// The compact size the accessibility text sizes use, also asked for by the Status layout when
    /// the map would not fit under the design hero (REQ-SURF-013).
    var prefersCompact = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.coldStartHeroNamespace) private var coldStartHeroNamespace

    private var isCompact: Bool {
        dynamicTypeSize.isAccessibilitySize || prefersCompact
    }

    private var ringDiameter: CGFloat {
        isCompact ? Theme.RedesignHeroSizes.ax5RingDiameter : Theme.RedesignHeroSizes.ringDiameter
    }

    private var discDiameter: CGFloat {
        isCompact ? Theme.RedesignHeroSizes.ax5DiscDiameter : Theme.RedesignHeroSizes.discDiameter
    }

    private var accentColor: Color {
        Theme.RedesignColors.statusAccent(for: accent)
    }

    private var tints: Theme.RedesignStatusTints {
        Theme.RedesignColors.tints(for: accentColor)
    }

    var body: some View {
        ZStack {
            glow
            if showsSymbol {
                // A filled circle symbol's glyph is drawn the size of the disc it replaces.
                Image(systemName: symbolName)
                    .font(.system(size: discDiameter * Self.symbolScale, weight: .regular))
                    .foregroundStyle(accentColor)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                    // Only matters when `showsSymbol` toggles false → true within one view's
                    // lifetime — the cold-start hand-off's disc-then-symbol reveal.
                    .transition(.scale.combined(with: .opacity))
            } else {
                disc
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .modifier(ColdStartHeroMatchedGeometry(namespace: coldStartHeroNamespace, isSource: !isColdStartHandoffCopy))
    }

    /// The symbol's point size against the disc: a circle symbol's circle is about 0.85 of it.
    private static let symbolScale: CGFloat = 0.95

    /// Approximates geometry-and-tokens.md §1's radial glow (20% of the accent, centered, fading
    /// out). A `RadialGradient` with an explicit end radius, not `Circle().blur(...)`: SwiftUI's
    /// `.blur` doesn't clip to the shape's frame, so a blurred circle washed out the screen.
    private var glow: some View {
        RadialGradient(
            colors: [tints.glow, tints.glow.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: ringDiameter * 0.9
        )
        .frame(width: ringDiameter * 1.8, height: ringDiameter * 1.8)
        .allowsHitTesting(false)
    }

    private var disc: some View {
        Circle()
            .fill(tints.soft)
            .overlay(Circle().strokeBorder(tints.edge, lineWidth: 1))
            .frame(width: discDiameter, height: discDiameter)
    }
}

#if DEBUG
    #Preview("Hero graphic — clear") {
        StatusHeroGraphic(accent: .clear, symbolName: "checkmark.circle.fill")
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.RedesignColors.background)
    }

    #Preview("Hero graphic — disc only (cold start, pre-symbol)") {
        StatusHeroGraphic(accent: .alert, symbolName: "exclamationmark.circle.fill", showsSymbol: false)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.RedesignColors.background)
    }
#endif
