import CoreGraphics

/// REQ-SURF-013: the whole map fits before the hero keeps its size. On a display that is short for
/// its width, such as the open iPhone Duo in landscape, a full-width map card is taller than the
/// screen; the owner's priority is the map, so the hero gives way first and the map is narrowed
/// only after that.
struct StatusLayout: Equatable {
    var usesCompactHero: Bool
    /// The map card's width cap; `nil` lets it take the full content width.
    var mapMaxWidth: CGFloat?
    /// STATUS-two-states AC-8: how much the hero ring grows into spare height (1 = design size).
    var heroScale: CGFloat = 1
    /// Spare height beyond the ring's cap, put once above the hero and once before the map.
    var heroGap: CGFloat = 0

    /// The ring grows to at most 1.6x its design size (156 pt to about 250 pt).
    static let maxHeroScale: CGFloat = 1.6
    /// About one reason line with its spacing, kept free when the line is absent, so the line coming
    /// or going on a poll never resizes the ring.
    static let reasonLineReserve: CGFloat = 24
    /// The map card keeps the screen's usual inset above the tab bar when the hero grows.
    static let bottomMargin = Theme.RedesignSpacing.screenInset

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
        mapAspectRatio: CGFloat,
        hasReasonLine: Bool = true,
        allowsGrowth: Bool = true
    ) -> StatusLayout {
        guard visibleHeight > 0, contentWidth > 0, mapAspectRatio > 0 else { return .design }
        let fullMapHeight = contentWidth / mapAspectRatio
        if heightAboveMap + fullMapHeight <= visibleHeight {
            let reserve = hasReasonLine ? 0 : reasonLineReserve
            let spare = visibleHeight - heightAboveMap - fullMapHeight - reserve - bottomMargin
            guard allowsGrowth, spare > 0 else { return .design }
            let ring = Theme.RedesignHeroSizes.ringDiameter
            let growth = min(spare, ring * (maxHeroScale - 1))
            return StatusLayout(
                usesCompactHero: false, mapMaxWidth: nil, heroScale: 1 + growth / ring, heroGap: (spare - growth) / 2)
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
        /// The ring growth the hero was laid out with, taken back out so the answer never feeds on
        /// itself (as `heroShrink` is added back for the compact hero).
        var heroScale: CGFloat = 1
        var hasReasonLine = true
        var allowsGrowth = true
    }

    var visibleHeight: CGFloat = 0
    var contentWidth: CGFloat = 0
    var aboveMap = AboveMap()

    func layout() -> StatusLayout {
        StatusLayout.resolve(
            visibleHeight: visibleHeight,
            contentWidth: contentWidth,
            heightAboveMap: aboveMap.height
                - (aboveMap.heroScale - 1) * Theme.RedesignHeroSizes.ringDiameter
                + (aboveMap.isCompactHero ? StatusLayout.heroShrink : 0),
            mapAspectRatio: AlertMapCard.aspectRatio,
            hasReasonLine: aboveMap.hasReasonLine,
            allowsGrowth: aboveMap.allowsGrowth
        )
    }
}
