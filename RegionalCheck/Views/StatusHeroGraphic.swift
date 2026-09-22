import SwiftUI

/// The ring + glow + disc + status symbol, shared by `StatusHeroCard` (the Status tab's live hero)
/// and `ColdStartHeroView`'s known-accent phases (the cold-start overlay's hand-off moment).
/// Pulled out of `StatusHeroCard` rather than kept as two hand-synchronized implementations: the
/// cold-start overlay drew its own copy of this geometry from `geometry-and-tokens.md` before
/// `StatusHeroCard` existed, and by the time both did, they'd already drifted — full symbol size
/// vs. 55%, a glow layer vs. none, a 1 pt disc stroke vs. 0.7 pt. One view means one place left to
/// drift.
struct StatusHeroGraphic: View {
    let accent: Theme.RedesignStatusAccent
    let symbolName: String
    var isAlertActive = false
    var isChecking = false
    /// `false` for the cold-start overlay's disc-grows-in-before-symbol-springs-in step
    /// (`ColdStartTiming.symbolDelay`) — `StatusHeroCard` never needs this, since the Status tab
    /// has no equivalent two-step reveal.
    var showsSymbol = true
    /// `true` only for `ColdStartHeroView`'s instance. `StatusHeroCard`'s copy is the one thing on
    /// screen the whole time the hand-off happens, so it's the geometry source
    /// (`matchedGeometryEffect`'s `isSource: true`); the overlay's copy is the transient one that
    /// gets pulled onto the real hero's actual frame, wherever the Status tab's `ScrollView` and an
    /// optional map card above it happen to have put it that launch — never a hardcoded offset that
    /// would drift the moment either view's layout changes.
    var isColdStartHandoffCopy = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.coldStartHeroNamespace) private var coldStartHeroNamespace

    private var isAX5: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var ringDiameter: CGFloat {
        isAX5 ? Theme.RedesignHeroSizes.ax5RingDiameter : Theme.RedesignHeroSizes.ringDiameter
    }

    private var ringRadius: CGFloat {
        isAX5 ? Theme.RedesignHeroSizes.ax5RingRadius : Theme.RedesignHeroSizes.ringRadius
    }

    private var discDiameter: CGFloat {
        isAX5 ? Theme.RedesignHeroSizes.ax5DiscDiameter : Theme.RedesignHeroSizes.discDiameter
    }

    private var symbolSize: CGFloat {
        isAX5 ? Theme.RedesignHeroSizes.ax5SymbolSize : Theme.RedesignHeroSizes.symbolSize
    }

    private var tickLength: CGFloat {
        isAX5 ? Theme.RedesignHeroSizes.ax5TickLength : Theme.RedesignHeroSizes.tickLength
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
            if !isColdStartHandoffCopy {
                radar
            }
            tickRing
            disc
            if showsSymbol {
                // See `StatusHeroCard`'s original comment: `HostProcess.isUnitTesting` also gates
                // the repeating effects, not just `reduceMotion` — Prefire captures whatever phase
                // a repeating symbol effect happens to be mid-cycle at, which made snapshots flake
                // between otherwise-identical runs the same way the tick ring's own rotation once did.
                Image(systemName: symbolName)
                    .font(.system(size: symbolSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accentColor)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: symbolName)
                    .symbolEffect(
                        .pulse,
                        options: .repeating,
                        isActive: isAlertActive && !reduceMotion && !HostProcess.isUnitTesting
                    )
                    .symbolEffect(
                        .rotate,
                        options: .repeating,
                        isActive: isChecking && !reduceMotion && !HostProcess.isUnitTesting
                    )
                    .accessibilityHidden(true)
                    // Only matters when `showsSymbol` toggles false → true within one view's
                    // lifetime — the cold-start hand-off's disc-then-symbol reveal. `StatusHeroCard`
                    // always passes the default `true`, so this never plays for it.
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .modifier(ColdStartHeroMatchedGeometry(namespace: coldStartHeroNamespace, isSource: !isColdStartHandoffCopy))
    }

    /// Approximates geometry-and-tokens.md §1's 460×380 pt radial glow (20% of the accent,
    /// centered on the ring, fading to 0 at 72%). A `RadialGradient` with an explicit end radius,
    /// not `Circle().blur(...)`: SwiftUI's `.blur` doesn't clip to the shape's frame, so a blurred
    /// circle bled out far past the hero and washed out most of the screen.
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

    /// One radar turn, in seconds.
    private static let radarPeriod: Double = 4

    private var isRadarStill: Bool {
        reduceMotion || HostProcess.isUnitTesting
    }

    /// An always-on radar inside the ticks, in the status colour (owner, 2026-09-21: the app is
    /// watching, whatever the status). It reads as a radar rather than a timer (owner reference,
    /// 2026-09-22): a light beam line on the leading edge and an afterglow fading out behind it,
    /// counter-clockwise, with no hard trailing edge; the app icon carries the same frame. A
    /// `TimelineView` drives the angle from the clock rather than a repeating animation, so it
    /// cannot drift or restart when the status changes. It holds still at the icon's pose under
    /// Reduce Motion and in the unit-test host: a moving beam would make Prefire snapshots differ
    /// between runs, the reason the tick ring itself does not rotate.
    private var radar: some View {
        // A clear gap before the ticks: an afterglow or beam running into them hid the ticks it
        // passed and made the beam look thicker at its tip (owner, TestFlight 116, 2026-09-22).
        let sweepRadius = ringRadius - tickLength - Self.radarTickGap
        let beamColor = accentColor.mix(with: .white, by: 0.45)
        return TimelineView(.animation(minimumInterval: 1.0 / 30, paused: isRadarStill)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.radarPeriod) / Self.radarPeriod
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            stops: [
                                .init(color: accentColor.opacity(0), location: 0),
                                .init(color: accentColor.opacity(0), location: 1 - Self.radarTrail),
                                .init(color: accentColor.opacity(0.3), location: 1),
                            ],
                            center: .center,
                            angle: .degrees(-90)
                        )
                    )
                // The beam starts at the disc's edge: the disc is translucent, and a line through
                // it would cross the status symbol. One even hairline, square-ended and without a
                // shadow, so nothing swells at its tip.
                Rectangle()
                    .fill(beamColor.opacity(0.9))
                    .frame(width: 1.5, height: sweepRadius - discDiameter / 2)
                    .offset(y: -(sweepRadius + discDiameter / 2) / 2)
            }
            .frame(width: sweepRadius * 2, height: sweepRadius * 2)
            .rotationEffect(.degrees(isRadarStill ? Self.radarStillAngle : turn * 360))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Points between the radar's reach and the ticks' inner edge.
    private static let radarTickGap: CGFloat = 4

    /// The afterglow behind the beam, as a fraction of a turn (50°).
    private static let radarTrail = 0.14

    /// Where the beam rests when it does not turn: the app icon's pose.
    private static let radarStillAngle: Double = 45

    private var disc: some View {
        Circle()
            .fill(tints.soft)
            .overlay(Circle().strokeBorder(tints.edge, lineWidth: 1))
            .frame(width: discDiameter, height: discDiameter)
    }

    /// 60 ticks, round caps, flat color (geometry-and-tokens.md §3): `ringSweep` while checking,
    /// `ringStatus` (accent 38%) once status is known — never a gradient. Static, not rotating: an
    /// earlier version animated a continuous sweep rotation, which made the Prefire snapshot
    /// non-deterministic (captured at whatever rotation angle happened to be mid-flight). The
    /// checking symbol's own `.symbolEffect(.rotate, ...)` already carries the "in progress" cue.
    private var tickRing: some View {
        ZStack {
            ForEach(0 ..< Theme.RedesignHeroSizes.tickCount, id: \.self) { index in
                Capsule()
                    .fill(tickColor)
                    .frame(width: Theme.RedesignHeroSizes.tickWidth, height: tickLength)
                    .offset(y: -ringRadius)
                    .rotationEffect(.degrees(Double(index) * (360 / Double(Theme.RedesignHeroSizes.tickCount))))
            }
        }
    }

    private var tickColor: Color {
        isChecking ? Theme.RedesignColors.ringSweep : accentColor.opacity(Theme.RedesignColors.ringStatusOpacity)
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
