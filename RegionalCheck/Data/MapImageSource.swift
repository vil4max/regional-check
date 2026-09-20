import Foundation

/// Raster variant of the upstream Ubilling alert map.
///
/// `nightmode` is the neutral dark render. `rednight` exists upstream but is
/// deliberately not offered: a red tint is indistinguishable from alarm color.
enum MapImageVariant: String, Equatable, Sendable {
    case day
    case night

    var mapParameter: String {
        switch self {
        case .day:
            "true"
        case .night:
            "nightmode"
        }
    }
}

/// Builds the on-demand upstream map image URL. Pure and side-effect free.
///
/// The image is fetched only when the Map tab appears or the user refreshes it.
/// Statuses always come from the shared JSON snapshot; the raster adds no data.
enum MapImageSource: Sendable {
    /// Width over height of the upstream raster, 1000 × 670 px in both variants (measured
    /// 2026-09-21). The inline card reserves this shape before the image decodes; if upstream
    /// changes its size the image letterboxes inside the card instead of moving the layout.
    static let aspectRatio: CGFloat = 1000.0 / 670.0

    static func url(for variant: MapImageVariant) -> URL {
        var components = URLComponents(string: "https://ubilling.net.ua/aerialalerts/")
        components?.queryItems = [URLQueryItem(name: "map", value: variant.mapParameter)]
        guard let url = components?.url else {
            preconditionFailure("Upstream map base URL must stay valid")
        }
        return url
    }
}
