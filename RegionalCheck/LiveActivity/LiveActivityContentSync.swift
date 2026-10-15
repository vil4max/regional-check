import DriveCheckKit
import Foundation

extension LiveActivityControlling {
    /// The one mapping from what the phone shows to what the Live Activity shows. Every caller
    /// that changes the status pushes through here, so the activity never shows other content.
    func syncContent(from status: StatusController) {
        update(
            phase: status.state.phase.activityPhase,
            regionTitle: status.regionTitle,
            checkedAt: status.state.checkedAt,
            sourceLabel: StatusSourceLabel.displayName(for: status.lastSourceRaw),
            isStale: status.isDataStale
        )
    }
}

extension StatusState.Phase {
    var activityPhase: DriveCheckActivityPhase {
        switch self {
        case .idle:
            .idle
        case .quiet:
            .quiet
        case .alarm:
            .alarm
        case .error, .regionUnavailable:
            .error
        }
    }
}
