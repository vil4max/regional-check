import DriveCheckKit
import SwiftUI

enum DriveCheckWidgetTokens {
    static let background = DriveCheckColors.background
    static let statusClear = DriveCheckColors.statusClear
    static let statusAlert = DriveCheckColors.statusAlert
    static let statusStale = DriveCheckColors.statusStale
    /// Old data, as the app's hero shows it (REQ-SURF-010 traffic light: grey, never yellow).
    static let statusNoData = DriveCheckColors.statusNoData
    static let statusChecking = DriveCheckColors.statusChecking
    static let textPrimary = DriveCheckColors.textPrimary
    static let textSecondary = DriveCheckColors.textSecondary

    /// Never on a status-bearing element (5.1); used only for the Pro refresh glyph background.
    static let proAccent = DriveCheckColors.proAccent

    /// The leading glyph color, from the shared `presentationAccent` decision (DriveCheckKit,
    /// unit-tested there) mapped to the shared color values.
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

    static func background(accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [background, background.mix(with: accent, by: 0.12, in: .device)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
