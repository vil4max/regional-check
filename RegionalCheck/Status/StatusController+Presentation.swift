import DriveCheckKit

/// The traffic-light status of the controller's current data, derived once for every phone
/// surface (the Status hero, the Details summary bar and the cold-start overlay), so they never
/// show different colours for the same data. Stale beats the phase except for an alarm.
extension StatusController {
    var presentation: StatusPresentation {
        StatusPresentation(
            phase: state.phase.presentationPhase,
            isStale: isDataStale
        )
    }

    /// STATUS-api-only AC-4: a request in flight on old non-alarm data shows checking, not the grey
    /// clock, so loading never reads as old data. A stale alarm stays red (REQ-SURF-003).
    var isCheckingOldData: Bool {
        isLoading && Theme.RedesignStatusAccent(presentation) == .stale
    }

    var accent: Theme.RedesignStatusAccent {
        isCheckingOldData ? .checking : Theme.RedesignStatusAccent(presentation)
    }

    var heroSymbolName: String {
        isCheckingOldData ? Theme.RedesignStatusAccent.checking.symbolName : presentation.symbolName
    }
}
