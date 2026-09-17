import Foundation
@testable import RegionalCheck
import Testing

/// RD-2: status accent mapping, palette selection, and the Reduce Transparency glass fallback
/// (`docs/tasks/rd-2-theme-tokens.md` "Tests"). Pure logic only — no snapshot coverage here.
struct ThemeRedesignTests {

    // MARK: - Status accent mapping

    @Test
    func statusAccentMapsEveryAccentToItsToken() {
        // `RedesignColors.statusAccent` takes no `RedesignPalette` argument — status colors live
        // outside `RedesignPalette` entirely, so no palette branch can diverge them regardless of which
        // palette is active (docs/tasks/rd-2-theme-tokens.md failure condition: "a palette overrides a
        // status color"; §2 "Status colors ... are identical in both palettes").
        #expect(Theme.RedesignColors.statusAccent(for: .clear) == Theme.RedesignColors.statusClear)
        #expect(Theme.RedesignColors.statusAccent(for: .alert) == Theme.RedesignColors.statusAlert)
        #expect(Theme.RedesignColors.statusAccent(for: .stale) == Theme.RedesignColors.statusStale)
        #expect(Theme.RedesignColors.statusAccent(for: .checking) == Theme.RedesignColors.statusChecking)
    }

    @Test
    func statusAccentCoversEveryStatusStatePhasePlusStale() {
        #expect(Theme.RedesignStatusAccent(phase: .quiet, isStale: false) == .clear)
        #expect(Theme.RedesignStatusAccent(phase: .alarm, isStale: false) == .alert)
        #expect(Theme.RedesignStatusAccent(phase: .idle, isStale: false) == .checking)
        #expect(Theme.RedesignStatusAccent(phase: .error, isStale: false) == .checking)
        #expect(Theme.RedesignStatusAccent(phase: .regionUnavailable, isStale: false) == .checking)
    }

    @Test
    func statusAccentStaleFlagOverridesEveryPhase() {
        for phase: StatusState.Phase in [.idle, .quiet, .alarm, .error, .regionUnavailable] {
            #expect(Theme.RedesignStatusAccent(phase: phase, isStale: true) == .stale)
        }
    }

    // MARK: - Palette selection

    @Test
    func paletteSelectionFollowsProEntitlement() {
        #expect(Theme.RedesignPalette.current(isProEntitled: false) == .standard)
        #expect(Theme.RedesignPalette.current(isProEntitled: true) == .pro)
    }

    @Test
    func paletteSelectionChangesWhenEntitlementChanges() {
        var isProEntitled = false
        #expect(Theme.RedesignPalette.current(isProEntitled: isProEntitled) == .standard)
        isProEntitled = true
        #expect(Theme.RedesignPalette.current(isProEntitled: isProEntitled) == .pro)
        isProEntitled = false
        #expect(Theme.RedesignPalette.current(isProEntitled: isProEntitled) == .standard)
    }

    @Test
    func chromeTokensDifferBetweenPalettesWhileSharedTokensDoNot() {
        #expect(Theme.RedesignPalette.standard.tabSelectedLabel != Theme.RedesignPalette.pro.tabSelectedLabel)
        // `proChipFill` is documented as identical in both palettes (§2).
        #expect(Theme.RedesignPalette.standard.proChipFill == Theme.RedesignPalette.pro.proChipFill)
    }

    // MARK: - Reduce Transparency fallback

    @Test
    func glassFillUsesBarGlassWhenReduceTransparencyIsOff() {
        #expect(Theme.RedesignGlass.fill(reduceTransparency: false) == Theme.RedesignColors.barGlass)
    }

    @Test
    func glassFillUsesSolidFallbackWhenReduceTransparencyIsOn() {
        #expect(Theme.RedesignGlass.fill(reduceTransparency: true) == Theme.RedesignColors.glassFallback)
    }

    // MARK: - Tints

    @Test
    func tintsDeriveOpacityFromTheGivenColor() {
        let tints = Theme.RedesignColors.tints(for: Theme.RedesignColors.statusAlert)
        #expect(tints.soft == Theme.RedesignColors.statusAlert.opacity(0.14))
        #expect(tints.edge == Theme.RedesignColors.statusAlert.opacity(0.40))
        #expect(tints.glow == Theme.RedesignColors.statusAlert.opacity(0.20))
        #expect(tints.shadow == Theme.RedesignColors.statusAlert.opacity(0.30))
    }
}
