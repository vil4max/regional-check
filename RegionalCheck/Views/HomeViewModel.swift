import DriveCheckKit
import Foundation

@MainActor
protocol HomeStatusSource: AnyObject {
    var state: StatusState { get }
    var regionTitle: String { get }
    var isLoading: Bool { get }
    var isDataStale: Bool { get }
    var hasRefreshFailed: Bool { get }
    func refresh() async
}

extension StatusController: HomeStatusSource {
    func refresh() async {
        await refresh(isScheduled: false)
    }
}

@MainActor
@Observable
final class HomeViewModel {
    private let status: any HomeStatusSource
    private let location: any HomeLocationSource
    private let settings: any SettingsOpening
    private let syncLiveActivityContent: () -> Void

    init(
        status: any HomeStatusSource,
        location: any HomeLocationSource,
        settings: any SettingsOpening,
        syncLiveActivityContent: @escaping () -> Void
    ) {
        self.status = status
        self.location = location
        self.settings = settings
        self.syncLiveActivityContent = syncLiveActivityContent
    }

    var showsLocationAccessDenied: Bool {
        location.isAuthorizationBlocked
    }

    /// The location-denied card's route to the app's page in Settings.
    func openLocationSettings() {
        settings.openSettings()
    }

    func refresh() async {
        await status.refresh()
        syncLiveActivityContent()
    }

    private(set) var pullRefreshFeedback: PullRefreshFeedback?

    /// Only the pull gesture comes here. A refresh the fetch floor held reads as completed: no
    /// request means the data is fresh enough, and the next refresh will bring anything newer.
    func pullToRefresh() async {
        await refresh()
        pullRefreshFeedback = PullRefreshFeedback(
            outcome: status.hasRefreshFailed ? .failed : .completed,
            sequence: (pullRefreshFeedback?.sequence ?? 0) + 1
        )
    }
}

/// The outcome of the driver's last pull to refresh, for its haptic (REQ-REFRESH-011).
/// `sequence` makes each pull a new value, so two pulls with the same outcome both play.
struct PullRefreshFeedback: Equatable {
    enum Outcome {
        case completed
        case failed
    }

    let outcome: Outcome
    let sequence: Int
}
