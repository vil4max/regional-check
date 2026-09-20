import CarPlay
import DriveCheckKit
import UIKit

/// Reads the real maximum a `CPListImageRowItemCardElement` will render at (a `class var`, so
/// no live template or interface controller is needed) — injectable so builder tests can
/// simulate a real car's number, a zero size, or an absurd one without a CarPlay scene.
@MainActor
protocol CarPlayMapImageSizing {
    var maximumCardImageSize: CGSize { get }
}

struct LiveCarPlayMapImageSizing: CarPlayMapImageSizing {
    var maximumCardImageSize: CGSize {
        CPListImageRowItemCardElement.maximumFullHeightImageSize
    }
}

enum CarPlayMapImageScaling {
    /// No real car screen exceeds this in points; a reported maximum past it is not a size to
    /// trust, not a size to honor (RD-9 failure condition: "an absurd maximumImageSize").
    private static let implausibleDimension: CGFloat = 4000

    /// Scales `image` to fit within `maximum` without cropping or upscaling past the source's
    /// own resolution (the redesign never crops the upstream raster). `nil` for a `maximum` that
    /// isn't a size to trust — zero, negative, NaN, or implausibly large — the same fallback
    /// path as a missing or undecodable image, per RD-9's failure conditions.
    static func scaledToFit(_ image: UIImage, maximum: CGSize) -> UIImage? {
        guard
            maximum.width > 0, maximum.height > 0,
            maximum.width <= implausibleDimension, maximum.height <= implausibleDimension,
            image.size.width > 0, image.size.height > 0
        else {
            return nil
        }
        let scale = min(maximum.width / image.size.width, maximum.height / image.size.height, 1)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

/// Holds the last scaled raster so a render does not decode and redraw it again.
///
/// `CarPlaySceneDelegate.render` rebuilds the Map tab's sections on every tick, whichever tab is
/// on screen, and the scaling is a synchronous full decode plus an off-screen redraw of the whole
/// raster on the main actor — the owner's head unit went unresponsive while switching tabs. The
/// image only changes when a new load lands, so one entry is enough: the key is the load time,
/// the byte count and the car's maximum size, which together change exactly when the result would.
@MainActor
final class CarPlayScaledImageCache {
    private struct Key: Equatable {
        let loadedAt: Date
        let byteCount: Int
        let maximum: CGSize
    }

    private var key: Key?
    private var image: UIImage?
    private(set) var scaleCount = 0

    func scaled(data: Data, loadedAt: Date, maximum: CGSize) -> UIImage? {
        let requested = Key(loadedAt: loadedAt, byteCount: data.count, maximum: maximum)
        if requested == key {
            return image
        }
        scaleCount += 1
        key = requested
        image = UIImage(data: data).flatMap { CarPlayMapImageScaling.scaledToFit($0, maximum: maximum) }
        return image
    }
}

/// The upstream raster's load state, independent of the alert-status snapshot (it loads on Map
/// tab appear and "Refresh map" only, never a timer). A plain value type — driven from
/// `MapViewModel` by the scene delegate — so the builder stays pure and testable without a live
/// network stack.
struct CarPlayMapImageState: Equatable {
    let imageData: Data?
    let loadedAt: Date?
    let loadFailed: Bool

    static let notLoaded = CarPlayMapImageState(imageData: nil, loadedAt: nil, loadFailed: false)
}

/// Builds the CarPlay Map tab (§7.3, Variant B): header row with the Ubilling raster as a
/// `CPListImageRowItemCardElement`, a region count row, and a "Refresh map" row. REQ-SURF-006:
/// free, no Pro check anywhere in this builder.
///
/// The image row degrades to nothing — never a blank frame — whenever it cannot be shown as
/// current: never loaded, the last load failed, it failed to decode, its own age crosses the
/// same 2×-interval staleness threshold as the alert status (`DataFreshness`), or the reported
/// maximum size cannot fit any image. The count/refresh rows never depend on the image, so the
/// tab always has usable, honest content even when the picture cannot render.
@MainActor
struct CarPlayMapBuilder {
    private let status: StatusController
    private let imageSizing: any CarPlayMapImageSizing
    let scaledImages = CarPlayScaledImageCache()
    private let onRefresh: () -> Void

    init(
        status: StatusController,
        imageSizing: any CarPlayMapImageSizing = LiveCarPlayMapImageSizing(),
        onRefresh: @escaping () -> Void
    ) {
        self.status = status
        self.imageSizing = imageSizing
        self.onRefresh = onRefresh
    }

    func mapTemplate(loadState: CarPlayLoadState, freshness: CarPlayFreshness,
                     image: CarPlayMapImageState) -> CPListTemplate {
        let template = CPListTemplate(
            title: String(localized: "driver.map.tab_title"),
            sections: sections(loadState: loadState, freshness: freshness, image: image)
        )
        template.tabTitle = String(localized: "driver.map.tab_title")
        template.tabImage = UIImage(systemName: "map")
        // Nothing has ever been fetched: no count to show yet, same wording as the Details tab.
        template.emptyViewTitleVariants = [String(localized: "driver.status.no_current_data.title")]
        return template
    }

    func sections(loadState: CarPlayLoadState, freshness: CarPlayFreshness,
                  image: CarPlayMapImageState) -> [CPListSection] {
        guard let snapshot = loadState.snapshot else { return [] }
        var items: [CPListTemplateItem] = []
        if let imageRow = imageRow(image: image, freshness: freshness) {
            items.append(imageRow)
        }
        items.append(countItem(snapshot, freshness: freshness))
        items.append(refreshItem())
        return [CPListSection(items: items, header: nil, sectionIndexTitle: nil)]
    }

    /// `nil` whenever the image cannot be safely shown as current (see the type header for the
    /// full list of fallback triggers) — the tab then falls back to the count/refresh rows only.
    private func imageRow(image: CarPlayMapImageState, freshness: CarPlayFreshness) -> CPListImageRowItem? {
        guard !image.loadFailed, let data = image.imageData, let loadedAt = image.loadedAt else {
            return nil
        }
        guard !DataFreshness.isStale(
            checkedAt: loadedAt,
            now: freshness.now,
            refreshIntervalSeconds: freshness.refreshIntervalSeconds
        )
        else {
            return nil
        }
        guard let scaled = scaledImages.scaled(
            data: data,
            loadedAt: loadedAt,
            maximum: imageSizing.maximumCardImageSize
        ) else {
            return nil
        }
        let card = CPListImageRowItemCardElement(
            image: scaled,
            showsImageFullHeight: true,
            title: nil,
            subtitle: String(format: String(localized: "driver.map.updated"), freshness.ageText(since: loadedAt)),
            tintColor: nil
        )
        let row = CPListImageRowItem(
            text: String(localized: "driver.map.tab_title"),
            cardElements: [card],
            allowsMultipleLines: false
        )
        // The raster carries no region semantics of its own; the snapshot is the only honest
        // source for what it means (same reasoning as the phone map card's a11y label).
        row.accessibilityLabel = mapAccessibilityLabel(snapshot: status.lastSnapshot)
        return row
    }

    /// "{n} of {total} regions under alert", or the clear-state copy at zero. Stale (no current
    /// data): the same count, with its age appended — the real, last-known number stays visible,
    /// never a status color, matching the Behavior spec.
    private func countItem(_ snapshot: CarPlaySnapshot, freshness: CarPlayFreshness) -> CPListItem {
        // Iterate `allCases` (fixed order), not the snapshot dictionary: deterministic listing.
        let statuses = status.lastSnapshot?.statuses ?? [:]
        let alertedRegions = AlertRegion.allCases.filter { statuses[$0] == .alarm }
        let baseText = alertedRegions.isEmpty
            ? String(localized: "driver.map.clear")
            : String(format: String(localized: "driver.map.count"), alertedRegions.count, AlertRegion.allCases.count)
        // A localized key, not string concatenation with a literal " · ": matches the Status
        // tab's own fresh/stale pattern (`driver.status.mode_updated`/`.mode_last_update`) rather
        // than a second, ungoverned way of joining text that ru/uk never got a chance to review.
        let text = freshness.isFresh(snapshot)
            ? baseText
            : String(format: String(localized: "driver.map.count_stale"), baseText, freshness.ageText(for: snapshot))
        return CPListItem(
            text: text,
            detailText: alertedRegions.isEmpty ? nil : affectedListText(alertedRegions)
        )
    }

    /// At most 3 names, then "and N more" — mirrors `CarPlayDetailsBuilder.ukraineAffectedListText`
    /// (kept local rather than shared: that file belongs to RD-8).
    private func affectedListText(_ regions: [AlertRegion]) -> String {
        let shown = regions.prefix(3).map(\.title).joined(separator: ", ")
        let remaining = regions.count - min(3, regions.count)
        guard remaining > 0 else { return shown }
        // Deliberately two localized pieces joined by a plain space, not one combined key: ru/uk
        // "и ещё %lld"/"і ще %lld" drop the noun entirely, which is what keeps the count phrase
        // plural-safe with no variations needed. A single "%@ and %lld more regions"-style key
        // would put the noun back in and reintroduce that problem. The space isn't a translation
        // decision the way "·" is — nothing here belongs inside a format string.
        return shown + " " + String(format: String(localized: "driver.details.and_more"), remaining)
    }

    private func refreshItem() -> CPListItem {
        let item = CPListItem(text: String(localized: "driver.map.refresh"), detailText: nil)
        item.handler = { [onRefresh] _, completion in
            onRefresh()
            completion()
        }
        return item
    }
}
