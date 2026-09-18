import DriveCheckKit
import Foundation

@MainActor
protocol HomeStatusSource: AnyObject {
    var state: StatusState { get }
    var regionTitle: String { get }
    var isLoading: Bool { get }
    var isDataStale: Bool { get }
    var lastSourceRaw: String? { get }
    /// RD-5: for the "Also watching" row's live status pill and the Summary card's segment bar —
    /// `StatusController` already stores this; only the protocol requirement is new.
    var lastSnapshot: AlertsSnapshot? { get }
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
    private let secondaryRegionStore: any SecondaryRegionStore
    private let syncLiveActivityContent: () -> Void

    init(
        status: any HomeStatusSource,
        location: any HomeLocationSource,
        subscription: any SubscriptionManaging,
        secondaryRegionStore: any SecondaryRegionStore,
        syncLiveActivityContent: @escaping () -> Void
    ) {
        self.status = status
        self.location = location
        self.subscription = subscription
        self.secondaryRegionStore = secondaryRegionStore
        self.syncLiveActivityContent = syncLiveActivityContent
    }

    var isPro: Bool {
        subscription.isPro
    }

    var sourceLabel: String? {
        subscription.allows(.extendedDetail)
            ? StatusSourceLabel.displayName(for: status.lastSourceRaw)
            : nil
    }

    var showsLocationAccessDenied: Bool {
        location.isAuthorizationBlocked
    }

    /// RD-5: the raw secondary region for the "Also watching" grouped-list row (replaces the old
    /// pre-formatted `secondaryRegionTitle` string — the redesigned row needs the region's own
    /// live status pill too, not just its name in a sentence).
    var secondaryRegion: AlertRegion? {
        guard isPro else { return nil }
        return secondaryRegionStore.loadSecondaryRegion()
    }

    var secondaryRegionStatus: AlertStatus? {
        guard let secondaryRegion else { return nil }
        return status.lastSnapshot?.status(for: secondaryRegion)
    }

    func refresh() async {
        await status.refresh()
        syncLiveActivityContent()
    }
}
