import CoreGraphics
@testable import RegionalCheck
import Testing

/// The toolbar backing itself is layout and is covered by the Status snapshots plus a live check.
/// No numbered requirement covers Reduce Transparency yet, so these cite none; the rule comes from
/// `docs/tasks/redesign.md` §11, the same source as `ThemeRedesignTests`' glass fallback.
struct StatusToolbarTests {
    @Test
    func backingFadesOverTheTokenDistanceByDefault() {
        #expect(StatusToolbar.fadeHeight(reduceTransparency: false) == Theme.RedesignSpacing.toolbarFade)
        #expect(Theme.RedesignSpacing.toolbarFade > 0)
    }

    @Test
    func backingEndsInAHardEdgeUnderReduceTransparency() {
        #expect(StatusToolbar.fadeHeight(reduceTransparency: true) == 0)
    }
}
