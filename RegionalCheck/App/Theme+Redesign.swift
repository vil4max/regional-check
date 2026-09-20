import SwiftUI

/// RD-2: "instrument cluster" design language tokens
/// (`docs/design/redesign/geometry-and-tokens.md`, §5.1–5.5 of `docs/tasks/redesign.md`).
///
/// Additive and dark-only (owner ruling R6): every token here lives next to the tokens in
/// `Theme`, which stay until each screen migrates (RD-4 … RD-10). Nothing in this file changes
/// an existing view. Types are prefixed `Redesign…` and kept as direct children of `Theme`
/// (rather than nested under an intermediate `Theme.Redesign` namespace) to stay within
/// `Tooling/.swiftlint.yml`'s default one-level `nesting` rule, which this task does not own.
/// `Theme.RedesignPalette` never carries a status color — the failure condition in
/// `docs/tasks/rd-2-theme-tokens.md` forbids a palette from overriding one — so status tokens
/// live only in `RedesignColors`.
extension Theme {
    enum RedesignColors {
        // Palette-independent — identical in every `RedesignPalette` (P2 honest signal, never themed).
        static let background = Color(red: 0.047, green: 0.055, blue: 0.067) // #0C0E11
        static let statusClear = Color(red: 0.486, green: 0.765, blue: 0.608) // #7CC39B
        static let statusAlert = Color(red: 0.941, green: 0.486, blue: 0.486) // #F07C7C
        static let statusStale = Color(red: 0.910, green: 0.729, blue: 0.384) // #E8BA62
        static let statusChecking = Color(red: 0.604, green: 0.627, blue: 0.659) // #9AA0A8
        /// Glyph color on the filled stale Refresh button; contrast-checked against `statusStale`.
        static let textOnStale = Color(red: 0.102, green: 0.078, blue: 0.031) // #1A1408

        /// Crown, PRO chip, paywall accents. Never on a status-bearing element (5.1). Replaces
        /// `Theme.Colors.onboarding`.
        static let proAccent = Color(red: 0.918, green: 0.843, blue: 0.690) // #EAD7B0

        static let textPrimary = Color(red: 0.949, green: 0.953, blue: 0.961) // #F2F3F5
        static let textBody = Color(red: 0.902, green: 0.910, blue: 0.925) // #E6E8EC
        static let textSecondary = Color(red: 0.639, green: 0.655, blue: 0.682) // #A3A7AE
        static let textTertiary = Color(red: 0.431, green: 0.451, blue: 0.482) // #6E737B

        static let surface = Color.white.opacity(0.06)
        static let surfaceStroke = Color.white.opacity(0.10) // card border
        static let buttonStroke = Color.white.opacity(0.12) // round button border
        static let separator = Color.white.opacity(0.08)

        /// Tab bar and round action button fill; prefer `.glassEffect()` where available (`RedesignGlass`).
        static let barGlass = Color(red: 0.157, green: 0.169, blue: 0.192).opacity(0.72) // #282B31 72%
        /// Solid fallback for `barGlass` under Reduce Transparency (11; `RedesignGlass.fill`).
        static let glassFallback = Color(red: 0.110, green: 0.122, blue: 0.141) // #1C1F24

        static let alertGroupFill = statusAlert.opacity(0.08)
        static let alertGroupStroke = statusAlert.opacity(0.22)

        // Hero ring (geometry-and-tokens.md §3).
        /// Base `ringIdle` (white 12%): the launch mark, and `RedesignPalette.standard`'s in-app ring.
        static let ringIdleBase = Color.white.opacity(0.12)
        static let ringSweep = textPrimary.opacity(0.70)
        static let ringStatusOpacity: Double = 0.38

        /// Status accent color for `accent`; identical for every `RedesignPalette` (P2 honest signal —
        /// never themed). Takes no palette argument by design: see the file header.
        static func statusAccent(for accent: RedesignStatusAccent) -> Color {
            switch accent {
            case .clear:
                statusClear
            case .alert:
                statusAlert
            case .stale:
                statusStale
            case .checking, .unavailable:
                statusChecking
            }
        }

        /// Derived tints of a status or accent color (5.1): `soft` 14% (disc fill, pills), `edge` 40%
        /// (disc stroke), `glow` 20% (radial glow), `shadow` 30% (blur 60).
        static func tints(for color: Color) -> RedesignStatusTints {
            RedesignStatusTints(
                soft: color.opacity(0.14),
                edge: color.opacity(0.40),
                glow: color.opacity(0.20),
                shadow: color.opacity(0.30)
            )
        }
    }

    /// The five states a status-bearing element can render (5.1). `.stale` is not a `StatusState`
    /// case — it is the orthogonal `isDataStale`/`isSnapshotStale` flag (see `HomeViewModel`,
    /// `StatusDetailsViewModel`) — so this type, not `StatusState`, is what `RedesignColors.statusAccent`
    /// switches on.
    enum RedesignStatusAccent: CaseIterable, Equatable, Sendable {
        case clear
        case alert
        case stale
        case checking
        case unavailable

        /// Unavailable and checking share a neutral color, but not their status wording.
        ///
        /// A stale alarm does not downgrade: a driver reading a red-to-amber change as "no alert"
        /// is the one failure this app must never produce (`docs/design/redesign/states.md` row 9,
        /// `docs/core.md` P2), and the widget and Live Activity already keep a known alarm red.
        /// Only the other phases lose their colour when stale — a stale clear signal is the
        /// dangerous one. Staleness of an alarm is still said, in the hero's meta line.
        init(phase: StatusState.Phase, isStale: Bool) {
            if isStale, phase != .alarm {
                self = .stale
                return
            }
            switch phase {
            case .quiet:
                self = .clear
            case .alarm:
                self = .alert
            case .idle:
                self = .checking
            case .error, .regionUnavailable:
                self = .unavailable
            }
        }
    }

    struct RedesignStatusTints: Equatable {
        let soft: Color
        let edge: Color
        let glow: Color
        let shadow: Color
    }

    /// Runtime chrome palette that follows the Pro entitlement (§2 "Pro palette"). Status colors,
    /// `background` and the hero ring stay in `RedesignColors` and are never themed — only non-status
    /// chrome differs here, so a palette cannot override a status color even by mistake.
    ///
    /// Tokens only: nothing renders with this palette today. Its one consumer was the custom bottom
    /// bar, deleted when `MainTabView` moved to a native `TabView`, and the environment key that
    /// carried it had no readers left. The table stays because it is the design side of PRO-VIS-1
    /// (premium colours, 3.2.0); whoever wires it up adds the readers and the injection together.
    enum RedesignPalette: CaseIterable, Equatable, Sendable {
        case standard
        case pro

        /// Selects the palette for the given Pro entitlement. Call again whenever the entitlement
        /// changes (purchase, restore, expiry) so dependents update live — palettes are stateless
        /// value types, not cached per launch.
        static func current(isProEntitled: Bool) -> Self {
            isProEntitled ? .pro : .standard
        }

        var proChipFill: Color {
            RedesignColors.proAccent.opacity(0.16) // identical in both palettes
        }

        var navButtonStroke: Color {
            switch self {
            case .standard: .white.opacity(0.12)
            case .pro: RedesignColors.proAccent.opacity(0.28)
            }
        }

        var navButtonFill: Color {
            switch self {
            case .standard: .white.opacity(0.07)
            case .pro: RedesignColors.proAccent.opacity(0.08)
            }
        }

        var tabSelectedFill: Color {
            switch self {
            case .standard: .white.opacity(0.12)
            case .pro: RedesignColors.proAccent.opacity(0.14)
            }
        }

        var tabSelectedLabel: Color {
            switch self {
            case .standard: .white
            case .pro: RedesignColors.proAccent
            }
        }

        var barStroke: Color {
            switch self {
            case .standard: .white.opacity(0.10)
            case .pro: RedesignColors.proAccent.opacity(0.22)
            }
        }

        /// Glass surface states only (5.1's "actionButtonStroke (glass states only)").
        var actionButtonStroke: Color {
            switch self {
            case .standard: .white.opacity(0.10)
            case .pro: RedesignColors.proAccent.opacity(0.28)
            }
        }

        /// Hero ring idle-state tick color, in-app only — the static launch screen always uses
        /// `.standard` (§2).
        var ringIdle: Color {
            switch self {
            case .standard: RedesignColors.ringIdleBase
            case .pro: RedesignColors.proAccent.opacity(0.14)
            }
        }
    }

    enum RedesignTypography {
        static let statusTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let screenTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let regionName = Font.system(.title3, design: .rounded).weight(.semibold)
        static let navTitle = Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let sectionHeader = Font.system(.footnote, design: .rounded).weight(.semibold)
        static let caption = Font.system(.caption, design: .rounded)
        static let proChip = Font.system(.caption2, design: .rounded).weight(.bold)

        static let statusTitleTracking: CGFloat = -0.6
        static let sectionHeaderTracking: CGFloat = 0.3
        static let proChipTracking: CGFloat = 0.4

        /// Tabular-digit rounded font for times and durations (5.2 "Meta line"), so digit widths
        /// stay fixed as a countdown or timestamp updates.
        static func tabularTime(_ style: Font.TextStyle = .subheadline) -> Font {
            Font.system(style, design: .rounded).monospacedDigit()
        }
    }

    enum RedesignSpacing {
        static let screenInset: CGFloat = 20
        /// Content starts below the 44 pt navigation row.
        static let contentTop: CGFloat = 44
        /// The Status toolbar's backing fades out over this distance below the row. The hero's top
        /// padding equals it, so at rest the fade ends exactly where content begins.
        static let toolbarFade: CGFloat = 12
    }

    /// Hero ring sizes (geometry-and-tokens.md §3, `docs/tasks/redesign.md` 5.3).
    enum RedesignHeroSizes {
        static let ringDiameter: CGFloat = 156
        static let ringRadius: CGFloat = 74
        static let tickCount = 60
        static let tickLength: CGFloat = 5
        static let tickWidth: CGFloat = 1.6
        static let discDiameter: CGFloat = 108
        static let symbolSize: CGFloat = 54
        static let titleSpacing: CGFloat = 14

        // RD-5: AX5 shrink (states.md row 8, "hero shrinks to 108 / 76 pt before any text
        // truncates"). Ring/disc/symbol/tick-radius scaled from the base set by the same
        // 108/156 ≈ 0.69 ratio the design gave for the ring; not in geometry-and-tokens.md, so
        // flagged in the RD-5 report as a minimal addition for drivecheck-product to confirm.
        static let ax5RingDiameter: CGFloat = 108
        static let ax5RingRadius: CGFloat = 51
        static let ax5DiscDiameter: CGFloat = 76
        static let ax5SymbolSize: CGFloat = 38
        static let ax5TickLength: CGFloat = 4
    }

    enum RedesignCardSizes {
        static let summaryRadius: CGFloat = 24
        static let groupedRadius: CGFloat = 22
        static let paddingHorizontal: CGFloat = 18
        static let paddingVertical: CGFloat = 16
        static let innerGap: CGFloat = 12
    }

    enum RedesignRowSizes {
        static let grouped: CGFloat = 52
        static let regionList: CGFloat = 44
        static let alertRegionList: CGFloat = 48
    }

    enum RedesignControlSizes {
        static let navButton: CGFloat = 44
        static let actionButton: CGFloat = 62
        static let tabBarHeight: CGFloat = 62
        static let tabBarRadius: CGFloat = 31
        static let tabBarToActionGap: CGFloat = 12
        static let tabBarBottomInset: CGFloat = 24
        static let minTouchTarget: CGFloat = 44
    }

    enum RedesignSegmentBarSizes {
        static let count = 25
        static let height: CGFloat = 6
        static let gap: CGFloat = 3
        static let radius: CGFloat = 3
    }

    /// Glass surface helpers for the tab bar and round buttons (5.1, 11). Cards stay flat translucent
    /// fills (`RedesignColors.surface`/`surfaceStroke`) and never use glass, per the design language in §5.
    enum RedesignGlass {
        /// The fill to use for glass chrome, honoring Reduce Transparency: `barGlass` normally, the
        /// opaque `glassFallback` when the system preference is on (11; pure so it is unit-testable
        /// without a live environment).
        static func fill(reduceTransparency: Bool) -> Color {
            reduceTransparency ? RedesignColors.glassFallback : RedesignColors.barGlass
        }
    }

    enum RedesignMotion {
        /// Opacity range for the alert glow overlay pulse (5.1 status tints "glow" 20%, 5.5).
        static let alertGlowPulseRange: ClosedRange<Double> = 0.04 ... 0.18
        static let alertPulse = Animation.easeInOut(duration: 1.15).repeatForever(autoreverses: true)
        /// Reduce Motion fallback for any redesign pulse/rotation: a 200 ms cross-fade (11, §4).
        static let reduceMotionCrossFade = Animation.easeInOut(duration: 0.2)

        /// The alert pulse animation, or the Reduce Motion cross-fade fallback (11: "no pulse, no
        /// rotation; cross-fade only").
        static func alertPulse(reduceMotion: Bool) -> Animation {
            reduceMotion ? reduceMotionCrossFade : alertPulse
        }
    }
}

/// Redesign glass surface modifier — `.glassEffect()` (iOS 26+) normally, the solid
/// `Theme.RedesignGlass.fill` color under Reduce Transparency (11).
private struct RedesignGlassSurfaceModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Theme.RedesignGlass.fill(reduceTransparency: true), in: shape)
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }
}

extension View {
    /// Applies the redesign's tab bar / round button glass surface (5.1 `barGlass`), falling back to a
    /// solid fill under Reduce Transparency. Not for cards, which stay flat translucent fills (§5).
    func redesignGlassSurface(in shape: some Shape = Capsule()) -> some View {
        modifier(RedesignGlassSurfaceModifier(shape: shape))
    }
}
