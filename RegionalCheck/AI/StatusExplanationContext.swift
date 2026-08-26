import DriveCheckKit
import Foundation

/// Projection of resolved application state supplied to the probabilistic model.
/// Deliberately minimal: identity and resolution facts only, no domain objects,
/// no settings, no subscription internals, no location.
struct StatusExplanationContext: Equatable, Sendable {
    enum Phase: String, Equatable, Sendable {
        case quiet
        case alarm
    }

    let regionID: String
    let regionTitle: String
    let phase: Phase
    let source: String
    let checkedAt: Date
}

/// Builds the model-facing context from the immutable explanation input.
/// The model describes this projection; StatusController remains authoritative.
struct StatusExplanationContextBuilder: Sendable {
    func makeContext(from input: StatusExplanationInput) -> StatusExplanationContext? {
        switch input.status.phase {
        case .quiet:
            break
        case .alarm:
            break
        case .idle, .error, .regionUnavailable:
            return nil
        }
        return StatusExplanationContext(
            regionID: input.region.rawValue,
            regionTitle: input.region.title,
            phase: input.status.phase == .quiet ? .quiet : .alarm,
            source: input.snapshot.source,
            checkedAt: input.status.checkedAt ?? input.snapshot.checkedAt
        )
    }
}
