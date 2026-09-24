import DriveCheckKit
import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    let provider: UbillingProvider
    let location: any CarPlayLocationSource
    let regions: RegionSelection
    let status: StatusController
    let subscription: SubscriptionManager
    let liveActivity: LiveActivityController
    let regionListViewModel: RegionListViewModel
    let mapViewModel: MapViewModel
    let statusDetailsViewModel: StatusDetailsViewModel
    let mainTabViewModel: MainTabViewModel
    let homeViewModel: HomeViewModel
    let detailsViewModel: DetailsViewModel
    let statusPersistence: any StatusPersisting
    let widgetReloader: any WidgetReloading

    #if DEBUG
        /// Development-only trace sink for the explanation agent workflow.
        let explanationTraces = ExplanationTraceStore()
    #else
        /// Release keeps the product surface free of engineering instrumentation.
        let explanationTraces: ExplanationTraceStore?
    #endif

    convenience init() {
        let statusPersistence = SharedStore.shared
        let widgetReloader = LiveWidgetReloader()
        self.init(
            provider: UbillingProvider(),
            location: LocationManager(),
            regions: RegionSelection(),
            subscription: SubscriptionManager(
                entitlementPersistence: statusPersistence,
                widgetReloader: widgetReloader
            ),
            statusPersistence: statusPersistence,
            widgetReloader: widgetReloader
        )
    }

    init(
        provider: UbillingProvider,
        location: any CarPlayLocationSource,
        regions: RegionSelection,
        subscription: SubscriptionManager,
        statusPersistence: any StatusPersisting,
        widgetReloader: any WidgetReloading,
        mapHTTPClient: any HTTPClient = URLSession.shared,
        mapSleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        statusDetailsSummarizer: (any StatusDetailsSummarizing)? = nil,
        refreshEnvironment: (any RefreshEnvironmentProviding)? = nil,
        locale: @escaping () -> Locale = { .current },
        now: @escaping () -> Date = { Date() },
        liveActivityPermission: any LiveActivityPermissionSource = SystemLiveActivityPermission()
    ) {
        self.provider = provider
        self.location = location
        self.regions = regions
        self.subscription = subscription
        self.statusPersistence = statusPersistence
        self.widgetReloader = widgetReloader
        status = StatusController(
            region: regions.selectedRegion,
            provider: provider,
            environmentProvider: refreshEnvironment,
            persistence: statusPersistence,
            widgetReloader: widgetReloader,
            now: now
        )
        liveActivity = LiveActivityController(
            allowsLiveActivity: { subscription.allows(.liveActivity) },
            entitlementChanges: { subscription.entitlementChanges() }
        )
        regionListViewModel = RegionListViewModel(statusSource: status, currentRegionSource: regions)
        mapViewModel = MapViewModel(
            statusSource: status,
            httpClient: mapHTTPClient,
            now: now,
            sleep: mapSleep
        )
        #if DEBUG
            let detailsTraces: ExplanationTraceStore? = explanationTraces
        #else
            explanationTraces = nil
            let detailsTraces: ExplanationTraceStore? = nil
        #endif
        statusDetailsViewModel = StatusDetailsViewModel(
            summarizer: statusDetailsSummarizer ?? Self.statusDetailsSummarizer(traces: detailsTraces),
            source: status,
            now: now,
            refreshInterval: { [status] in
                RefreshPolicy.baseIntervalSeconds(for: status.refreshEnvironment())
            },
            locale: locale
        )
        mainTabViewModel = MainTabViewModel(
            status: status,
            location: location,
            regions: regions,
            subscription: subscription,
            liveActivity: liveActivity,
            syncLiveActivityContent: { [status, liveActivity] in
                Self.syncLiveActivityContent(status: status, liveActivity: liveActivity)
            }
        )
        homeViewModel = HomeViewModel(
            status: status,
            location: location,
            subscription: subscription,
            syncLiveActivityContent: { [status, liveActivity] in
                Self.syncLiveActivityContent(status: status, liveActivity: liveActivity)
            }
        )
        detailsViewModel = DetailsViewModel(
            location: location,
            subscription: subscription,
            liveActivityPermission: liveActivityPermission,
            setLiveActivityEnabled: { [mainTabViewModel] enabled in
                mainTabViewModel.setLiveActivityEnabled(enabled)
            }
        )
    }

    func syncLiveActivityContent() {
        Self.syncLiveActivityContent(status: status, liveActivity: liveActivity)
    }

    private static func statusDetailsSummarizer(
        traces: ExplanationTraceStore?
    ) -> any StatusDetailsSummarizing {
        FallbackStatusDetailsProvider(
            primary: FoundationModelsStatusDetailsProvider(trace: traces),
            fallback: DeterministicStatusDetailsProvider(),
            trace: traces
        )
    }

    static func syncLiveActivityContent(
        status: StatusController,
        liveActivity: any LiveActivityControlling
    ) {
        liveActivity.update(
            phase: status.state.phase.activityPhase,
            regionTitle: status.regionTitle,
            checkedAt: status.state.checkedAt,
            sourceLabel: StatusSourceLabel.displayName(for: status.lastSourceRaw),
            isStale: status.isDataStale
        )
    }
}
