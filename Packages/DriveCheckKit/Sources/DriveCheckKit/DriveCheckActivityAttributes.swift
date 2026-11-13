import ActivityKit
import Foundation

public struct DriveCheckActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: DriveCheckActivityPhase
        public var regionTitle: String
        public var checkedAt: Date?
        public var sourceLabel: String
        public var isStale: Bool
        /// When the server first saw this region's alarm (REQ-SURF-014). Optional on purpose: a
        /// push from a server before 3.4 has no key and decodes as `nil`, and an app before 3.4
        /// ignores the key. Only the server knows it; the app carries what the activity shows.
        public var alertStartedAt: Date?

        public init(
            phase: DriveCheckActivityPhase,
            regionTitle: String,
            checkedAt: Date?,
            sourceLabel: String,
            isStale: Bool = false,
            alertStartedAt: Date? = nil
        ) {
            self.phase = phase
            self.regionTitle = regionTitle
            self.checkedAt = checkedAt
            self.sourceLabel = sourceLabel
            self.isStale = isStale
            self.alertStartedAt = alertStartedAt
        }
    }

    public init() {}
}

public enum DriveCheckActivityPhase: String, Codable, Hashable, Sendable {
    case idle
    case quiet
    case alarm
    case error

    public var symbolName: String {
        StatusPresentation.symbolName(for: presentationPhase)
    }

    public var titleKey: String {
        StatusPresentation.titleKey(for: presentationPhase)
    }

    /// RD-10 row 9: which accent a Live Activity or Home Screen widget should render this phase
    /// with. A known alarm never downgrades from `.alert` (REQ-REFRESH-009: "a known alarm stays
    /// red... never replaced"); a stale quiet status drops the reassuring `.clear` for `.stale`
    /// instead (failure condition: "a stale widget shows... a clear color").
    public func presentationAccent(isStale: Bool) -> WidgetPresentationAccent {
        switch self {
        case .alarm: .alert
        case .quiet: isStale ? .stale : .clear
        case .idle, .error: .checking
        }
    }

    /// The Live Activity's row 9 accent. Checking wins, because it means "no data yet"; old
    /// non-alarm data, errors included, is the widget's light grey and never yellow, which means
    /// "Stay Alert" only (REQ-SURF-010). The Live Activity never shows Stay Alert itself.
    public func liveActivityAccent(isStale: Bool) -> WidgetPresentationAccent {
        if self == .idle {
            return .checking
        }
        if isStale, self != .alarm {
            return .stale
        }
        return presentationAccent(isStale: false)
    }

    /// The Live Activity's symbol (ALERT-push AC-10, owner 2026-11-10): the shared one of
    /// `StatusPresentation`, so the app and the activity show the same siren and shield (owner,
    /// 2026-11-13). Only the activity adds the clock badge to a stale alarm.
    public func liveActivityGlyph(isStale: Bool) -> LiveActivityGlyph {
        let symbolName = StatusPresentation.liveActivity(phase: self, isStale: isStale).symbolName
        // A known alarm never downgrades (REQ-REFRESH-009); the badge says the data is old.
        let badge = self == .alarm && isStale ? StatusPresentation.staleSymbolName : nil
        return LiveActivityGlyph(symbolName: symbolName, badgeSymbolName: badge)
    }

    /// The line under the Live Activity's time. A stale alarm keeps its red title and icon, so
    /// this footer is the only sign that the alert may already be over (REQ-SURF-003): the
    /// activity cannot re-check while the app is not running.
    public func liveActivityFooter(isStale: Bool) -> LiveActivityFooter? {
        if self == .idle {
            return .checking
        }
        guard isStale else { return nil }
        return self == .alarm ? .mayBeOutdated : .lastKnown
    }
}

public enum LiveActivityFooter: Equatable, Sendable {
    /// "Updating…": no data yet.
    case checking
    /// "Last known: {status}", under the grey "No Current Data" title of old non-alarm data.
    case lastKnown
    /// "May be outdated. Open the app.", under a stale alarm that stays red.
    case mayBeOutdated
}

public enum WidgetPresentationAccent: Equatable, Sendable {
    case clear
    /// REQ-SURF-010 "Stay Alert"; decided by `WidgetStatusPresentation.accent`, never by a phase.
    case caution
    case alert
    case stale
    case checking
}

/// A Live Activity state's symbol, with an optional small badge drawn at its corner.
public struct LiveActivityGlyph: Equatable, Sendable {
    public let symbolName: String
    public let badgeSymbolName: String?

    public init(symbolName: String, badgeSymbolName: String?) {
        self.symbolName = symbolName
        self.badgeSymbolName = badgeSymbolName
    }
}
