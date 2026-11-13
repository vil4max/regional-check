import Foundation

/// The line a Live Activity shows under its state and region (REQ-SURF-014).
public enum LiveActivityDetail: Equatable, Sendable {
    /// "Started 12 minutes ago": a fresh alarm whose start the feed gives. The system advances it
    /// without pushes.
    case started(Date)
    /// "All clear at 08:54": the green all-clear, at the time of the first response that showed
    /// the region clear. The feed has no all-clear time of its own, so this is its closest honest
    /// value, at most one poll late (owner, 2026-11-13).
    case allClear(Date)
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
    case allClear(Date)
    /// "Updated: 08:54": the time of the data, the response's own.
    case updated(Date)
    case footer(LiveActivityFooter)
}

extension DriveCheckActivityAttributes.ContentState {
    /// The time of the data, shown in every state that has one, beside a fresh alarm's start too:
    /// it is the driver's one way to judge whether what the activity shows is current (owner,
    /// 2026-11-13). `checkedAt` is the response's own time. The all-clear line already says it.
    public var liveActivityUpdatedAt: Date? { checkedAt }

    /// The state and region, then the start of a fresh alarm or the all-clear time, the data time,
    /// then the footer sighted users read under it: a stale alarm's "may be outdated" is the only
    /// sign it may be over (REQ-SURF-003), so it is spoken too.
    public func liveActivitySpokenParts(isStale: Bool) -> [LiveActivitySpokenPart] {
        var parts: [LiveActivitySpokenPart] = [.state, .region]
        switch liveActivityDetail(isStale: isStale) {
        case .started(let start):
            parts.append(.started(start))
            if let liveActivityUpdatedAt { parts.append(.updated(liveActivityUpdatedAt)) }
        case .allClear(let time):
            parts.append(.allClear(time))
        case .checked(let time):
            parts.append(.updated(time))
        case .none:
            break
        }
        if let footer = phase.liveActivityFooter(isStale: isStale) {
            parts.append(.footer(footer))
        }
        return parts
    }

    /// `isStale` is the activity's own staleness or the system's (`context.isStale`). A stale
    /// alarm may already be over (REQ-SURF-003), so it shows its check time and nothing counts.
    /// A fresh quiet activity is the green all-clear: an activity runs only during an alarm and
    /// turns green only when it ends on the all-clear.
    public func liveActivityDetail(isStale: Bool) -> LiveActivityDetail {
        if phase == .alarm, !isStale, let alertStartedAt {
            return .started(alertStartedAt)
        }
        if phase == .quiet, !isStale, let checkedAt {
            return .allClear(checkedAt)
        }
        if let checkedAt {
            return .checked(checkedAt)
        }
        return .none
    }
}
