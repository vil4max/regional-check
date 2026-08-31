import DriveCheckKit
import Foundation

@MainActor
protocol HomeStatusSource: AnyObject {
    var state: StatusState { get }
    var regionTitle: String { get }
    var isLoading: Bool { get }
    var isDataStale: Bool { get }
    var lastSourceRaw: String? { get }
    func refresh() async
}

@MainActor
protocol HomeLocationSource: AnyObject {
    var isAuthorizationBlocked: Bool { get }
}

extension StatusController: HomeStatusSource {}
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

    var secondaryRegionTitle: String? {
        guard isPro, let region = secondaryRegionStore.loadSecondaryRegion() else { return nil }
        return String(format: String(localized: "status.secondary_region"), region.title)
    }

    func refresh() async {
        await status.refresh()
        syncLiveActivityContent()
    }
}
