import DriveCheckKit
import Observation

@MainActor
@Observable
final class AppContainer {
    let provider: UbillingProvider
    let location: LocationManager
    let regions: RegionSelection
    let status: StatusController
    let subscription: SubscriptionManager
    let liveActivity: LiveActivityController
    let regionsViewModel: RegionsViewModel
    let statusExplanationViewModel: StatusExplanationViewModel
    let countrySummaryViewModel: CountrySummaryViewModel
    let mainTabViewModel: MainTabViewModel
    let statusPersistence: any StatusPersisting
    let secondaryRegionStore: any SecondaryRegionStore
    let widgetReloader: any WidgetReloading

    #if DEBUG
        /// Development-only trace sink for the explanation agent workflow.
        let explanationTraces = ExplanationTraceStore()
    #else
        /// Release keeps the product surface free of engineering instrumentation.
        let explanationTraces: ExplanationTraceStore?
    #endif

    convenience init() {
        self.init(
            provider: UbillingProvider(),
            location: LocationManager(),
            regions: RegionSelection(),
            subscription: SubscriptionManager(),
            statusPersistence: SharedStore.shared,
            secondaryRegionStore: SharedStore.shared,
            widgetReloader: LiveWidgetReloader()
        )
    }

    init(
        provider: UbillingProvider,
        location: LocationManager,
        regions: RegionSelection,
        subscription: SubscriptionManager,
        statusPersistence: any StatusPersisting,
        secondaryRegionStore: any SecondaryRegionStore,
        widgetReloader: any WidgetReloading
    ) {
        self.provider = provider
        self.location = location
        self.regions = regions
        self.subscription = subscription
        self.statusPersistence = statusPersistence
        self.secondaryRegionStore = secondaryRegionStore
        self.widgetReloader = widgetReloader
        status = StatusController(
            region: regions.selectedRegion,
            provider: provider,
            persistence: statusPersistence,
            widgetReloader: widgetReloader
        )
        liveActivity = LiveActivityController(
            allowsLiveActivity: { subscription.allows(.liveActivity) },
            entitlementChanges: { subscription.entitlementChanges() }
        )
        regionsViewModel = RegionsViewModel(
            statusSource: status,
            regionSelection: regions,
            locationProvider: location,
            premiumAccess: subscription,
            secondaryRegionStore: secondaryRegionStore,
            widgetReloader: widgetReloader
        )
        #if DEBUG
            statusExplanationViewModel = StatusExplanationViewModel(
                provider: Self.explanationProvider(status: status, traces: explanationTraces),
                context: status
            )
        #else
            explanationTraces = nil
            // Release keeps the product surface free of engineering
            // instrumentation; the composite itself is identical to DEBUG.
            statusExplanationViewModel = StatusExplanationViewModel(
                provider: Self.explanationProvider(status: status, traces: nil),
                context: status
            )
        #endif
        countrySummaryViewModel = CountrySummaryViewModel(
            summarizer: Self.countrySummarizer(status: status, traces: explanationTraces),
            source: status,
            refreshInterval: { [status] in
                RefreshPolicy.baseIntervalSeconds(for: status.refreshEnvironment())
            }
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
    }

    func syncLiveActivityContent() {
        Self.syncLiveActivityContent(status: status, liveActivity: liveActivity)
    }

    /// Foundation Models primary with deterministic local fallback. Device-validated
    /// on Apple Intelligence hardware (2026-08-26); on devices where Apple
    /// Intelligence is unavailable every run degrades to the localized explanation.
    private static func explanationProvider(
        status: StatusController,
        traces: ExplanationTraceStore?
    ) -> any StatusExplanationProviding {
        FallbackStatusExplanationProvider(
            primary: FoundationModelsExplanationProvider(
                environment: { await status.refreshEnvironment() },
                trace: traces
            ),
            fallback: LocalStatusExplanationProvider()
        )
    }

    /// Country overview composition: identical composite in both configurations;
    /// only the trace sink differs (dev-only instrumentation, nil in release).
    private static func countrySummarizer(
        status _: StatusController,
        traces: ExplanationTraceStore?
    ) -> any CountrySummarizing {
        FallbackCountrySummaryProvider(
            primary: FoundationModelsCountrySummaryProvider(trace: traces),
            fallback: DeterministicCountrySummaryProvider(),
            trace: traces
        )
    }

    private static func syncLiveActivityContent(
        status: StatusController,
        liveActivity: LiveActivityController
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
