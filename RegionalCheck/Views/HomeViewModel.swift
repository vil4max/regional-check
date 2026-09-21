import DriveCheckKit
import Foundation

@MainActor
protocol HomeStatusSource: AnyObject {
    var state: StatusState { get }
    var regionTitle: String { get }
    var isLoading: Bool { get }
    var isDataStale: Bool { get }
    var lastSourceRaw: String? { get }
    var hasRefreshFailed: Bool { get }
    func refresh() async
}

@MainActor
protocol HomeLocationSource: AnyObject {
    var isAuthorizationBlocked: Bool { get }
}

extension StatusController: HomeStatusSource {
    func refresh() async {
        await refresh(isScheduled: false)
    }
}

extension LocationManager: HomeLocationSource {}

@MainActor
@Observable
final class HomeViewModel {
    private let status: any HomeStatusSource
    private let location: any HomeLocationSource
    private let subscription: any SubscriptionManaging
    private let syncLiveActivityContent: () -> Void

    init(
        status: any HomeStatusSource,
        location: any HomeLocationSource,
        subscription: any SubscriptionManaging,
        syncLiveActivityContent: @escaping () -> Void
    ) {
        self.status = status
        self.location = location
        self.subscription = subscription
        self.syncLiveActivityContent = syncLiveActivityContent
    }

    var sourceLabel: String? {
        subscription.allows(.extendedDetail)
            ? StatusSourceLabel.displayName(for: status.lastSourceRaw)
            : nil
    }

    var showsLocationAccessDenied: Bool {
        location.isAuthorizationBlocked
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
