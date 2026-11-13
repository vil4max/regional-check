import DriveCheckKit
import Foundation

@MainActor
protocol LiveActivityControlling: AnyObject {
    func beginPhoneForegroundSession()
    func beginCarPlaySession()
    func endCarPlaySession()
    /// What the activity should show now, the app's own data (`alertStartedAt` from its feed).
    func update(_ state: DriveCheckActivityAttributes.ContentState)
    /// Ends the running activity. Session clients stay registered — only their own `end…Session`
    /// removes them.
    func endAll()
    /// Returns once every queued ActivityKit request has finished.
    func settle() async
}

extension LiveActivityControlling {
    /// The content without a known alarm start, as callers before REQ-SURF-014 sent it.
    func update(
        phase: DriveCheckActivityPhase, regionTitle: String, checkedAt: Date?, sourceLabel: String,
        isStale: Bool = false
    ) {
        update(
            DriveCheckActivityAttributes.ContentState(
                phase: phase, regionTitle: regionTitle, checkedAt: checkedAt, sourceLabel: sourceLabel,
                isStale: isStale))
    }
}

enum LiveActivitySessionClient: Hashable {
    case phoneForeground
    case carPlay
}
