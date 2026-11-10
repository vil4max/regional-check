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
    let proAppearance: ProAppearance
    let liveActivityPreference: LiveActivityPreferenceStore
    let liveActivity: LiveActivityController
    /// The server's Live Activity record, kept while Live Activities are allowed (ALERT-push).
    /// Wired at construction, so a launch with no scene (a push-to-start wake, the Refresh
    /// intent) still sends the tokens (AC-9).
    let liveActivityPush: LiveActivityPushRegistrar
    /// Built on first use: the unit-test host never reads it, so tests make no permission or
    /// network calls (REQ-PUSH-001).
    @ObservationIgnored lazy var pushRegistration = PushRegistrationController(regions: regions)
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
        let explanationTraces: ExplanationTraceStore? = nil
    #endif

    convenience init() {
        let statusPersistence = SharedStore.shared
        let widgetReloader = LiveWidgetReloader()
        self.init(
            provider: UbillingProvider(),
            location: LocationManager(),
            regions: RegionSelection(store: .shared, geocoder: TimeoutReverseGeocoder(base: MapKitReverseGeocoder())),
            subscription: SubscriptionManager(
                service: StoreKitSubscriptionService(),
                cache: EntitlementCache(
                    userDefaults: UserDefaults(suiteName: SharedStoreKeys.appGroup) ?? .standard,
                    legacyDefaults: .standard
                ),
                entitlementPersistence: statusPersistence,
                widgetReloader: widgetReloader
            ),
            statusPersistence: statusPersistence,
            widgetReloader: widgetReloader,
            refreshEnvironment: SystemRefreshEnvironmentProvider(),
            liveActivityHost: ActivityKitLiveActivityHost(),
            activityPushClient: URLSessionLiveActivityPushClient(),
            activityPushDefaults: .standard
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
        refreshEnvironment: any RefreshEnvironmentProviding,
        liveActivityHost: any LiveActivityHosting,
        locale: @escaping () -> Locale = { .current },
        now: @escaping () -> Date = { Date() },
        liveActivityPermission: any LiveActivityPermissionSource = SystemLiveActivityPermission(),
        liveActivityPreference: LiveActivityPreferenceStore = LiveActivityPreferenceStore(),
        iconPresenter: (any AlternateIconPresenting)? = nil,
        proDefaults: UserDefaults = .standard,
        settingsOpener: any SettingsOpening = SystemSettingsOpener(),
        // Only the live `init()` passes the network client and the standard defaults, so a test
        // or fixture container never reaches the server or a stored record.
        activityPushClient: any LiveActivityPushSending = OfflineLiveActivityPushClient(),
        activityPushDefaults: UserDefaults = UserDefaults(suiteName: "vil4max.RegionalCheck.offline") ?? .standard
    ) {
        self.provider = provider
        self.location = location
        self.regions = regions
        self.subscription = subscription
        proAppearance = ProAppearance(ownership: subscription, defaults: proDefaults, iconPresenter: iconPresenter)
        self.liveActivityPreference = liveActivityPreference
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
        status.follow(regions)
        liveActivity = Self.liveActivity(liveActivityPreference, subscription, liveActivityPermission, liveActivityHost)
        liveActivityPush = Self.liveActivityPush(regions, liveActivity, activityPushClient, activityPushDefaults)
        regionListViewModel = RegionListViewModel(statusSource: status, currentRegionSource: regions)
        mapViewModel = MapViewModel(statusSource: status, httpClient: mapHTTPClient, now: now, sleep: mapSleep)
        statusDetailsViewModel = Self.statusDetailsViewModel(
            status: status, summarizer: statusDetailsSummarizer, traces: explanationTraces, now: now, locale: locale
        )
        mainTabViewModel = Self.mainTab(status, location, regions, liveActivityPreference, liveActivity)
        homeViewModel = HomeViewModel(
            status: status,
            location: location,
            settings: settingsOpener,
            syncLiveActivityContent: { [status, liveActivity] in liveActivity.syncContent(from: status) }
        )
        detailsViewModel = DetailsViewModel(
            location: location,
            liveActivityPreference: liveActivityPreference,
            liveActivityPermission: liveActivityPermission,
            setLiveActivityEnabled: { [mainTabViewModel] in mainTabViewModel.setLiveActivityEnabled($0) },
            status: status,
            features: subscription,
            settings: settingsOpener
        )
    }

    /// Shows the all-clear switch on Details and keeps the server's region in step. Called by the
    /// phone scene and by the CarPlay scene provider, so a CarPlay-only launch also follows
    /// region changes (REQ-PUSH-001).
    func startPushRegistration() {
        detailsViewModel.allClearPush = pushRegistration
        pushRegistration.onUrgentChange = { [liveActivityPush] in liveActivityPush.urgentDidChange() }
        pushRegistration.startObservingRegionChanges()
    }

    func syncLiveActivityContent() {
        liveActivity.syncContent(from: status)
    }
}
