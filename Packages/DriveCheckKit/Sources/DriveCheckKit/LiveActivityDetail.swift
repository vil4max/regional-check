import Foundation

/// The line a Live Activity shows under its state and region (REQ-SURF-014).
public enum LiveActivityDetail: Equatable, Sendable {
    /// "Started 12 minutes ago": a fresh alarm whose start the server knows. The system advances
    /// it without pushes.
    case started(Date)
    /// The time of the last check, for every other state that has one.
    case checked(Date)
    case none
}

/// One part of what VoiceOver says for a Live Activity drawn as a single symbol (compact,
/// minimal), in order (REQ-SURF-014 clause 4).
public enum LiveActivitySpokenPart: Equatable, Sendable {
    case state
    case region
    case started(Date)
    case footer(LiveActivityFooter)
}

extension DriveCheckActivityAttributes.ContentState {
    /// The state and region, then how long ago a fresh alarm started, then the footer sighted users
    /// read under it: a stale alarm's "may be outdated" is the only sign it may be over
    /// (REQ-SURF-003), so it is spoken too.
    public func liveActivitySpokenParts(isStale: Bool) -> [LiveActivitySpokenPart] {
        var parts: [LiveActivitySpokenPart] = [.state, .region]
        if case .started(let start) = liveActivityDetail(isStale: isStale) {
            parts.append(.started(start))
        }
        if let footer = phase.liveActivityFooter(isStale: isStale) {
            parts.append(.footer(footer))
        }
        return parts
    }

    /// `isStale` is the activity's own staleness or the system's (`context.isStale`). A stale
    /// alarm may already be over (REQ-SURF-003), so it shows its check time and nothing counts.
    public func liveActivityDetail(isStale: Bool) -> LiveActivityDetail {
        if phase == .alarm, !isStale, let alertStartedAt {
            return .started(alertStartedAt)
        }
        if let checkedAt {
            return .checked(checkedAt)
        }
        return .none
    }
}
