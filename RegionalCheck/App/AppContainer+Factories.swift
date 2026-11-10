import DriveCheckKit
import Foundation

extension AppContainer {
    func makeProSheetViewModel() -> ProSheetViewModel {
        ProSheetViewModel(purchases: subscription, icon: proAppearance)
    }

    // Positional factories keep the composition root's init a readable list of what is built.

    static func liveActivity(
        _ preference: LiveActivityPreferenceStore,
        _ subscription: SubscriptionManager,
        _ permission: any LiveActivityPermissionSource,
        _ host: any LiveActivityHosting
    ) -> LiveActivityController {
        LiveActivityController(
            preference: preference,
            entitlementChanges: { subscription.entitlementChanges() },
            liveActivityPermission: permission,
            host: host
        )
    }

    /// The registrar, already receiving the controller's tokens and following the region.
    static func liveActivityPush(
        _ regions: RegionSelection,
        _ liveActivity: LiveActivityController,
        _ client: any LiveActivityPushSending,
        _ defaults: UserDefaults
    ) -> LiveActivityPushRegistrar {
        let registrar = LiveActivityPushRegistrar(regions: regions, client: client, defaults: defaults)
        liveActivity.tokenSink = registrar
        registrar.startObservingRegionChanges()
        return registrar
    }

    static func mainTab(
        _ status: StatusController,
        _ location: any CarPlayLocationSource,
        _ regions: RegionSelection,
        _ preference: LiveActivityPreferenceStore,
        _ liveActivity: LiveActivityController
    ) -> MainTabViewModel {
        MainTabViewModel(
            status: status,
            location: location,
            regions: regions,
            liveActivityPreference: preference,
            liveActivity: liveActivity,
            syncLiveActivityContent: { liveActivity.syncContent(from: status) }
        )
    }

    static func statusDetailsViewModel(
        status: StatusController,
        summarizer: (any StatusDetailsSummarizing)?,
        traces: ExplanationTraceStore?,
        now: @escaping () -> Date,
        locale: @escaping () -> Locale
    ) -> StatusDetailsViewModel {
        StatusDetailsViewModel(
            summarizer: summarizer ?? statusDetailsSummarizer(traces: traces),
            source: status,
            now: now,
            refreshInterval: { [status] in
                RefreshPolicy.baseIntervalSeconds(for: status.refreshEnvironment())
            },
            locale: locale
        )
    }

    static func statusDetailsSummarizer(
        traces: ExplanationTraceStore?
    ) -> any StatusDetailsSummarizing {
        FallbackStatusDetailsProvider(
            primary: FoundationModelsStatusDetailsProvider(trace: traces),
            fallback: DeterministicStatusDetailsProvider(),
            trace: traces
        )
    }
}
