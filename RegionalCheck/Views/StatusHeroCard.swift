import SwiftUI

/// RD-5: full-form status titles ("No Alert", "Air Raid Alert", "No Current Data", "Checking…";
/// owner ruling R3, `docs/tasks/redesign.md` §6.1 state table). Reuses existing, already-translated
/// catalog keys rather than inventing new copy: `"All Clear"` → "No Alert" and `"Checking…"` are
/// the Status tab's own keys (`StatusController.StatusState.title`, not owned by RD-5); the alarm
/// and stale full forms reuse the CarPlay tab's `driver.status.full.alarm` / `.no_current_data.title`
/// keys, which already carry the exact English/ru/uk text this state table asks for.
extension Theme.RedesignStatusAccent {
    var fullTitle: String {
        switch self {
        case .clear:
            String(localized: "All Clear")
        case .alert:
            String(localized: "driver.status.full.alarm")
        case .stale:
            String(localized: "driver.status.no_current_data.title")
        case .checking:
            String(localized: "Checking…")
        }
    }
}

/// RD-5: the hero's meta line, one per state (`docs/tasks/redesign.md` §6.1 state table):
/// "{Automatic|Manual} · Updated HH:mm" for clear/alert, "Last known: {status} · HH:mm" for stale,
/// "{Automatic|Manual} · Locating" for checking. Pure so `HomeViewModelTests` can cover every
/// combination without a live view; reuses `driver.status.mode.*`/`mode_updated` (existing) and
/// the two new `status.meta.*` keys this task adds.
enum StatusMetaLine {
    static func text(
        accent: Theme.RedesignStatusAccent,
        followsLocation: Bool,
        checkedAt: Date?,
        lastKnownTitle: String?
    ) -> String {
        let mode = String(localized: followsLocation ? "driver.status.mode.automatic" : "driver.status.mode.manual")
        switch accent {
        case .clear, .alert:
            let time = checkedAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
            return String(format: String(localized: "driver.status.mode_updated"), mode, time)
        case .checking:
            return "\(mode) · \(String(localized: "status.meta.locating"))"
        case .stale:
            let time = checkedAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
            let known = lastKnownTitle ?? String(localized: "Unavailable")
            return String(format: String(localized: "status.meta.last_known"), known, time)
        }
    }
}

/// RD-5: the Status hero — tick ring, disc, status symbol, full-form title, region row, and meta
/// line (`docs/tasks/redesign.md` §6.1; geometry-and-tokens.md §3). AX5 shrinks the ring/disc/
/// symbol before any text here truncates (states.md row 8); Reduce Motion turns the tick sweep and
/// symbol effects into a plain cross-fade.
struct StatusHeroCard: View {
    let accent: Theme.RedesignStatusAccent
    let symbolName: String
    let isAlertActive: Bool
    let isChecking: Bool
    let regionTitle: String
    let metaText: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        VStack(spacing: Theme.RedesignHeroSizes.titleSpacing) {
            ZStack {
                glow
                tickRing
                disc
                // `HostProcess.isUnitTesting` (existing app-wide convention) also gates the
                // repeating effects, not just `reduceMotion`: Prefire captures whatever phase a
                // repeating symbol effect happens to be mid-cycle at, which made
                // `Hero-checking`/`Status-alert-Pro` snapshots flake between otherwise-identical
                // runs the same way the tick ring's own rotation once did.
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
            }
            .frame(width: ringDiameter, height: ringDiameter)

            Text(accent.fullTitle)
                .font(Theme.RedesignTypography.statusTitle)
                .tracking(Theme.RedesignTypography.statusTitleTracking)
                .foregroundStyle(accentColor)
                .contentTransition(.interpolate)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.footnote)
                    Text(regionTitle)
                        .font(Theme.RedesignTypography.regionName)
                        .lineLimit(2)
                }
                .foregroundStyle(Theme.RedesignColors.textPrimary)

                Text(metaText)
                    .font(Theme.RedesignTypography.tabularTime(.subheadline))
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        // Matches redesign.md §11: "hero reads '{status}, {region}, updated {time}'".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(accent.fullTitle), \(regionTitle), \(metaText)"))
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
    // Checking and stale aren't reachable through `AppContainer.fixture()` (see the note on
    // `StatusView`'s previews), so they're previewed here at the component level with literal
    // values instead of a live `StatusController`.
    #Preview("Hero checking") {
        StatusHeroCard(
            accent: .checking,
            symbolName: "arrow.triangle.2.circlepath",
            isAlertActive: false,
            isChecking: true,
            regionTitle: "Kyiv Oblast",
            metaText: StatusMetaLine.text(accent: .checking, followsLocation: true, checkedAt: nil, lastKnownTitle: nil)
        )
        .padding()
        .background(Theme.RedesignColors.background)
    }

    #Preview("Hero stale") {
        StatusHeroCard(
            accent: .stale,
            symbolName: "clock",
            isAlertActive: false,
            isChecking: false,
            regionTitle: "Kyiv Oblast",
            metaText: StatusMetaLine.text(
                accent: .stale,
                followsLocation: true,
                checkedAt: Date(timeIntervalSince1970: 1_789_555_260),
                lastKnownTitle: "No Alert"
            )
        )
        .padding()
        .background(Theme.RedesignColors.background)
    }
#endif
