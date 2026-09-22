import ActivityKit
import Foundation

public struct DriveCheckActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: DriveCheckActivityPhase
        public var regionTitle: String
        public var checkedAt: Date?
        public var sourceLabel: String
        public var isStale: Bool

        public init(
            phase: DriveCheckActivityPhase,
            regionTitle: String,
            checkedAt: Date?,
            sourceLabel: String,
            isStale: Bool = false
        ) {
            self.phase = phase
            self.regionTitle = regionTitle
            self.checkedAt = checkedAt
            self.sourceLabel = sourceLabel
            self.isStale = isStale
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
        switch self {
        case .alarm:
            "exclamationmark.circle.fill"
        case .quiet:
            "checkmark.circle.fill"
        case .idle:
            "arrow.triangle.2.circlepath"
        case .error:
            "questionmark.circle.fill"
        }
    }

    public var titleKey: String {
        switch self {
        case .alarm:
            "Alert Active"
        case .quiet:
            "All Clear"
        case .idle:
            "Checking…"
        case .error:
            "Unavailable"
        }
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
}

public enum WidgetPresentationAccent: Equatable, Sendable {
    case clear
    /// REQ-SURF-010 "Stay Alert"; decided by `WidgetStatusPresentation.accent`, never by a phase.
    case caution
    case alert
    case stale
    case checking
}
