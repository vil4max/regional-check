import CoreGraphics
@testable import RegionalCheck
import Testing

/// REQ-SURF-013 on the sizes the iPhone 17 and the iPhone Duo give the Status scroll view. The
/// heights above the map are the design hero with its reason line and the stack's spacing.
struct StatusLayoutTests {
    private let aspect = AlertMapCard.aspectRatio
    private let heightAboveMap: CGFloat = 390

    @Test("REQ-SURF-013 where the hero and the full-width map fill the height, both keep their design sizes")
    func exactFitKeepsTheDesign() {
        let layout = StatusLayout.resolve(
            visibleHeight: heightAboveMap + 362 / aspect,
            contentWidth: 362,
            heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect
        )

        #expect(layout == .design)
    }

    @Test("STATUS-two-states AC-8 a little spare height grows the ring by that height, with no gap")
    func smallSpareGrowsTheRing() {
        let layout = StatusLayout.resolve(
            visibleHeight: heightAboveMap + 362 / aspect + StatusLayout.bottomMargin + 30,
            contentWidth: 362,
            heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect
        )

        #expect(!layout.usesCompactHero)
        #expect(abs(layout.heroScale - (1 + 30 / Theme.RedesignHeroSizes.ringDiameter)) < 0.001)
        #expect(layout.heroGap == 0)
    }

    @Test("STATUS-two-states AC-8 a large iPhone caps the ring at 1.6x and splits the rest into gaps")
    func largeSpareCapsTheRing() {
        // A large iPhone: about 180 pt left under the map at the design sizes.
        let spare: CGFloat = 180
        let layout = StatusLayout.resolve(
            visibleHeight: heightAboveMap + 398 / aspect + StatusLayout.bottomMargin + spare,
            contentWidth: 398,
            heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect
        )

        let growth = Theme.RedesignHeroSizes.ringDiameter * (StatusLayout.maxHeroScale - 1)
        #expect(abs(layout.heroScale - StatusLayout.maxHeroScale) < 0.001)
        #expect(abs(layout.heroGap - (spare - growth) / 2) < 0.01)
        #expect(layout.mapMaxWidth == nil)
    }

    @Test("STATUS-two-states AC-8 the reason line coming or going does not resize the ring")
    func reasonLineDoesNotResize() {
        let visible = heightAboveMap + 362 / aspect + 60
        let without = StatusLayout.resolve(
            visibleHeight: visible, contentWidth: 362, heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect, hasReasonLine: false)
        let with = StatusLayout.resolve(
            visibleHeight: visible, contentWidth: 362, heightAboveMap: heightAboveMap + StatusLayout.reasonLineReserve,
            mapAspectRatio: aspect, hasReasonLine: true)

        #expect(without == with)
        #expect(without.heroScale > 1)
    }

    @Test("STATUS-two-states AC-8 accessibility sizes keep the compact ring and never grow it")
    func accessibilitySizesDoNotGrow() {
        let layout = StatusLayout.resolve(
            visibleHeight: heightAboveMap + 362 / aspect + 180, contentWidth: 362, heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect, allowsGrowth: false)

        #expect(layout.heroScale == 1)
        #expect(layout.heroGap == 0)
    }

    @Test("STATUS-two-states AC-8 measuring the grown hero it asked for leaves the layout unchanged")
    func measuringTheGrownHeroIsStable() {
        var metrics = StatusLayoutMetrics(visibleHeight: heightAboveMap + 398 / aspect + 120, contentWidth: 398)
        metrics.aboveMap = .init(height: heightAboveMap, isCompactHero: false)
        let first = metrics.layout()
        let grownHeight = heightAboveMap + (first.heroScale - 1) * Theme.RedesignHeroSizes.ringDiameter

        metrics.aboveMap = .init(height: grownHeight, isCompactHero: false, heroScale: first.heroScale)

        #expect(first.heroScale > 1)
        #expect(metrics.layout() == first)
    }

    @Test("REQ-SURF-013 the hero shrinks first when that alone lets the full-width map fit")
    func duoOuterDisplayShrinksOnlyTheHero() {
        // Duo outer display: the full-width map overshoots by less than the hero gives up.
        let width: CGFloat = 336
        let visible = heightAboveMap + width / aspect - StatusLayout.heroShrink / 2
        let layout = StatusLayout.resolve(
            visibleHeight: visible,
            contentWidth: width,
            heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect
        )

        #expect(layout == StatusLayout(usesCompactHero: true, mapMaxWidth: nil))
    }

    @Test("REQ-SURF-013 a map still too tall after the hero shrinks is narrowed to the height left")
    func duoOpenLandscapeNarrowsTheMap() throws {
        // Open Duo in landscape: 826 pt wide, about 600 pt tall, so a full-width map is 553 pt tall.
        let visible: CGFloat = 600
        let layout = StatusLayout.resolve(
            visibleHeight: visible,
            contentWidth: 826,
            heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect
        )

        #expect(layout.usesCompactHero)
        let width = try #require(layout.mapMaxWidth)
        let heightLeft = visible - (heightAboveMap - StatusLayout.heroShrink)
        #expect(abs(width / aspect - heightLeft) < 0.5)
        #expect(width < 826)
    }

    @Test("REQ-SURF-013 a map that would fit only below its minimum width keeps its full width and scrolls")
    func shortViewportKeepsTheFullWidth() {
        let layout = StatusLayout.resolve(
            visibleHeight: 400,
            contentWidth: 826,
            heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect
        )

        #expect(layout == StatusLayout(usesCompactHero: true, mapMaxWidth: nil))
    }

    @Test("REQ-SURF-013 measuring the compact hero it asked for leaves the layout unchanged")
    func measuringTheCompactHeroIsStable() {
        var metrics = StatusLayoutMetrics(visibleHeight: 600, contentWidth: 826)
        metrics.aboveMap = .init(height: heightAboveMap, isCompactHero: false)
        let first = metrics.layout()

        metrics.aboveMap = .init(height: heightAboveMap - StatusLayout.heroShrink, isCompactHero: first.usesCompactHero)

        #expect(first.usesCompactHero)
        #expect(metrics.layout() == first)
    }

    @Test("REQ-SURF-013 before the view is measured the design sizes stay")
    func unmeasuredViewKeepsTheDesign() {
        let layout = StatusLayout.resolve(
            visibleHeight: 0,
            contentWidth: 0,
            heightAboveMap: 0,
            mapAspectRatio: aspect
        )

        #expect(layout == .design)
    }
}
