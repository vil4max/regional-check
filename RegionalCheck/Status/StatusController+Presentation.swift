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

    var accent: Theme.RedesignStatusAccent {
        Theme.RedesignStatusAccent(presentation)
    }
}
