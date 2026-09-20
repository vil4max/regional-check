import DriveCheckKit
import Foundation

@MainActor
protocol LiveActivityControlling: AnyObject {
    func beginPhoneForegroundSession()
    func endPhoneForegroundSession()
    func beginCarPlaySession()
    func endCarPlaySession()
    func update(
        phase: DriveCheckActivityPhase,
        regionTitle: String,
        checkedAt: Date?,
        sourceLabel: String,
        isStale: Bool
    )
    /// Ends the running activity. Session clients stay registered — only their own `end…Session`
    /// removes them.
    func endAll()
}

enum LiveActivitySessionClient: Hashable {
    case phoneForeground
    case carPlay
}
