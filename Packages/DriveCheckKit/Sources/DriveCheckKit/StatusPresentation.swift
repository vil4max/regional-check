import Foundation

/// The status word and glyph of one status, shared by every surface, so the same data never reads
/// or looks different from one surface to the next (`docs/core.md` UI keys,
/// `docs/design/redesign/states.md` row 9). The widgets, the control and the Live Activity read
/// their catalog key and SF Symbol here. The phone hero takes its glyph and its accent (through
/// `StatusController.presentation`) but not the word: it shows the longer full-form titles.
/// Colours stay with each target, so this type needs no UI framework. Each target localizes
/// `titleKey` in its own String Catalog.
public struct StatusPresentation: Equatable, Sendable {
    public enum Phase: CaseIterable, Equatable, Sendable {
        case idle
        case quiet
        case alarm
        /// A request failed and nothing is known: "Unavailable".
        case error
        /// The data has no status for the region: "Region Unavailable".
        case regionUnavailable
    }

    public static let staleSymbolName = "clock.fill"
    public static let cautionSymbolName = "exclamationmark.triangle.fill"
    public static let cautionTitleKey = "status.caution.title"

    public let phase: Phase
    public let isStale: Bool
    /// REQ-SURF-010: half or more of the region's neighbours, or most of the country, are under alert.
    public let isSurrounded: Bool

    public init(phase: Phase, isStale: Bool, isSurrounded: Bool = false) {
        self.phase = phase
        self.isStale = isStale
        self.isSurrounded = isSurrounded
    }

    /// The yellow "Stay Alert" status: a fresh quiet region surrounded by alerts. Stale
    /// neighbours are as old as the region's own status, so stale data never is.
    public var isCaution: Bool {
        phase == .quiet && isSurrounded && !isStale
    }

    /// Old data that is not an alarm gives up its status glyph for the clock, so a checkmark always
    /// means a fresh "No Alert". A known alarm never downgrades (REQ-REFRESH-009).
    public var showsStaleGlyph: Bool {
        isStale && phase != .alarm
    }

    /// The short status word. Staleness does not change it: each surface says the data is old in
    /// its own way (a caption, a meta line or the Live Activity's own title).
    public var titleKey: String {
        isCaution ? Self.cautionTitleKey : Self.titleKey(for: phase)
    }

    public var symbolName: String {
        if showsStaleGlyph {
            return Self.staleSymbolName
        }
        return isCaution ? Self.cautionSymbolName : Self.symbolName(for: phase)
    }

    public static func titleKey(for phase: Phase) -> String {
        switch phase {
        case .idle: "Checking…"
        case .quiet: "All Clear"
        case .alarm: "Alert Active"
        case .error: "Unavailable"
        case .regionUnavailable: "Region Unavailable"
        }
    }

    public static func symbolName(for phase: Phase) -> String {
        switch phase {
        case .idle: "arrow.triangle.2.circlepath"
        case .quiet: "checkmark.circle.fill"
        case .alarm: "exclamationmark.circle.fill"
        case .error, .regionUnavailable: "questionmark.circle.fill"
        }
    }
}

extension StatusPresentation {
    /// The Live Activity's status. Checking always wins, because it means "no data yet" rather
    /// than "old data". The activity's content state carries no neighbours, so it never shows
    /// Stay Alert. Its `.error` covers both failures, so it reads the general "Unavailable".
    public static func liveActivity(phase: DriveCheckActivityPhase, isStale: Bool) -> StatusPresentation {
        StatusPresentation(phase: phase.presentationPhase, isStale: phase != .idle && isStale)
    }

    /// The status word where there is no room for a "Last known" caption next to it (the Live
    /// Activity, states.md row 9, and the Control Center control): old non-alarm data reads
    /// "No Current Data" rather than a last-known "No Alert" next to the clock.
    public var compactTitleKey: String {
        showsStaleGlyph ? "widget.status.noCurrentData" : titleKey
    }
}

extension DriveCheckActivityPhase {
    public var presentationPhase: StatusPresentation.Phase {
        switch self {
        case .idle: .idle
        case .quiet: .quiet
        case .alarm: .alarm
        case .error: .error
        }
    }
}
