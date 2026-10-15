import DriveCheckKit
import Foundation

struct StatusExplanationInput: Equatable, Sendable {
    let snapshot: AlertsSnapshot
    let region: AlertRegion
    let status: StatusState
}

@MainActor
protocol ExplanationStatusContext: AnyObject {
    var lastSnapshot: AlertsSnapshot? { get }
    var currentRegion: AlertRegion { get }
    var state: StatusState { get }
    var hasRefreshFailed: Bool { get }
}

extension ExplanationStatusContext {
    var hasRefreshFailed: Bool {
        false
    }
}

extension StatusController: ExplanationStatusContext {}
