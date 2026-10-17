import CoreGraphics
@testable import RegionalCheck
import Testing

/// REQ-SURF-013 on the sizes the iPhone 17 and the iPhone Duo give the Status scroll view. The
/// heights above the map are the design hero, the nearby line and the stack's spacing.
struct StatusLayoutTests {
    private let aspect = MapImageSource.aspectRatio
    private let heightAboveMap: CGFloat = 390

    @Test("REQ-SURF-013 where the hero and the full-width map fit, both keep their design sizes")
    func iPhone17PortraitKeepsTheDesign() {
        // iPhone 17 portrait: 362 pt of content width, about 684 pt between the title and the tab bar.
        let layout = StatusLayout.resolve(
            visibleHeight: 684,
            contentWidth: 362,
            heightAboveMap: heightAboveMap,
            mapAspectRatio: aspect
        )

        #expect(layout == .design)
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
        let first = metrics.layout(hasMap: true)

        metrics.aboveMap = .init(height: heightAboveMap - StatusLayout.heroShrink, isCompactHero: first.usesCompactHero)

        #expect(first.usesCompactHero)
        #expect(metrics.layout(hasMap: true) == first)
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
