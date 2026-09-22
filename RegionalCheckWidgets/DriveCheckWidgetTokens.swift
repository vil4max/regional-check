import DriveCheckKit
import SwiftUI

/// RD-10: mirrors the values in `docs/design/redesign/geometry-and-tokens.md` for the widget
/// extension target, which cannot import `RegionalCheck/App/Theme+Redesign.swift` (separate
/// target). Keep every value identical to that file; token changes come from drivecheck-product
/// through RD-2, not from this target.
enum DriveCheckWidgetTokens {
    static let background = Color(red: 0.047, green: 0.055, blue: 0.067) // #0C0E11
    static let statusClear = Color(red: 0.486, green: 0.765, blue: 0.608) // #7CC39B
    static let statusAlert = Color(red: 0.941, green: 0.486, blue: 0.486) // #F07C7C
    static let statusStale = Color(red: 0.910, green: 0.729, blue: 0.384) // #E8BA62
    /// Old data, as the app's hero shows it (REQ-SURF-010 traffic light: grey, never yellow).
    static let statusNoData = Color(red: 0.776, green: 0.792, blue: 0.816) // #C6CAD0
    static let statusChecking = Color(red: 0.604, green: 0.627, blue: 0.659) // #9AA0A8
    static let textPrimary = Color(red: 0.949, green: 0.953, blue: 0.961) // #F2F3F5
    static let textSecondary = Color(red: 0.639, green: 0.655, blue: 0.682) // #A3A7AE

    /// Never on a status-bearing element (5.1); used only for the Pro refresh glyph background.
    static let proAccent = Color(red: 0.918, green: 0.843, blue: 0.690) // #EAD7B0

    /// The leading glyph color, from the shared `presentationAccent` decision (DriveCheckKit,
    /// unit-tested there) mapped to this target's mirrored token values.
    static func iconColor(phase: DriveCheckActivityPhase, isStale: Bool) -> Color {
        iconColor(accent: phase.presentationAccent(isStale: isStale))
    }

    /// Yellow means "Stay Alert" only, as in the app; old data is grey (REQ-SURF-010).
    static func iconColor(accent: WidgetPresentationAccent) -> Color {
        switch accent {
        case .alert: statusAlert
        case .clear: statusClear
        case .caution: statusStale
        case .stale: statusNoData
        case .checking: statusChecking
        }
    }

    /// The status word color: same `.alert`/`.clear` as `iconColor`, but `.stale`/`.checking`
    /// read as plain `textPrimary` — only the leading glyph and the small "Last known" caption
    /// carry the stale/checking accent, so a stale word is never mistaken for "status unknown".
    static func titleColor(accent: WidgetPresentationAccent) -> Color {
        switch accent {
        case .alert: statusAlert
        case .clear: statusClear
        case .caution: statusStale
        case .stale, .checking: textPrimary
        }
    }

    /// The leading glyph: a known alarm keeps its own icon at any freshness; a stale non-alarm
    /// status shows the clock instead of its normal glyph, matching row 9's stale mockups.
    static func iconName(phase: DriveCheckActivityPhase, isStale: Bool, normal: String) -> String {
        phase != .alarm && isStale ? "clock.fill" : normal
    }

    static func background(accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [background, background.mix(with: accent, by: 0.12, in: .device)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
