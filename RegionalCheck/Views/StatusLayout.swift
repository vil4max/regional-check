import CoreGraphics

/// REQ-SURF-013: the whole map fits before the hero keeps its size. On a display that is short for
/// its width, such as the open iPhone Duo in landscape, a full-width map card is taller than the
/// screen; the owner's priority is the map, so the hero gives way first and the map is narrowed
/// only after that.
struct StatusLayout: Equatable {
    var usesCompactHero: Bool
    /// The map card's width cap; `nil` lets it take the full content width.
    var mapMaxWidth: CGFloat?

    static let design = StatusLayout(usesCompactHero: false, mapMaxWidth: nil)

    /// How much shorter the hero is at its compact size: `StatusHeroGraphic` lays out as a square
    /// of the ring diameter, and nothing else in the hero changes size with it.
    static let heroShrink = Theme.RedesignHeroSizes.ringDiameter - Theme.RedesignHeroSizes.ax5RingDiameter
    /// Narrower than this the region shapes stop reading; below it the page scrolls instead.
    static let minimumMapWidth: CGFloat = 280

    /// - Parameters:
    ///   - visibleHeight: the scroll view's height, from under the title row to the tab bar or the
    ///     home indicator.
    ///   - contentWidth: the width a full-width map card takes.
    ///   - heightAboveMap: the content above the map card, spacing included, as laid out with the
    ///     design hero. The caller adds `heroShrink` back when it measured a compact hero, so the
    ///     result never depends on its own previous answer.
    static func resolve(
        visibleHeight: CGFloat,
        contentWidth: CGFloat,
        heightAboveMap: CGFloat,
        mapAspectRatio: CGFloat
    ) -> StatusLayout {
        guard visibleHeight > 0, contentWidth > 0, mapAspectRatio > 0 else { return .design }
        let fullMapHeight = contentWidth / mapAspectRatio
        if heightAboveMap + fullMapHeight <= visibleHeight {
            return .design
        }
        let heightLeft = visibleHeight - (heightAboveMap - heroShrink)
        if fullMapHeight <= heightLeft {
            return StatusLayout(usesCompactHero: true, mapMaxWidth: nil)
        }
        let width = heightLeft * mapAspectRatio
        // A map narrowed below the minimum still would not fit; it keeps its full width and the
        // page scrolls, as at the accessibility text sizes on a phone.
        guard width >= minimumMapWidth else {
            return StatusLayout(usesCompactHero: true, mapMaxWidth: nil)
        }
        return StatusLayout(usesCompactHero: true, mapMaxWidth: width)
    }
}

/// What `StatusView` measures for `StatusLayout`, kept in one value so a measurement that arrives
/// before the others leaves the layout at its design sizes rather than half-resolved.
struct StatusLayoutMetrics: Equatable {
    /// The content above the map card, spacing included, and the hero size it was laid out with.
    struct AboveMap: Equatable {
        var height: CGFloat = 0
        var isCompactHero = false
    }

    var visibleHeight: CGFloat = 0
    var contentWidth: CGFloat = 0
    var aboveMap = AboveMap()

    func layout(hasMap: Bool) -> StatusLayout {
        guard hasMap else { return .design }
        return StatusLayout.resolve(
            visibleHeight: visibleHeight,
            contentWidth: contentWidth,
            heightAboveMap: aboveMap.height + (aboveMap.isCompactHero ? StatusLayout.heroShrink : 0),
            mapAspectRatio: MapImageSource.aspectRatio
        )
    }
}
