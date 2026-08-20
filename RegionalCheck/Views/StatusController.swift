import DriveCheckKit
import Foundation
import Observation
import os

@MainActor
protocol StatusPersisting {
    func saveRegion(_ region: AlertRegion)
    func saveSnapshot(_ snapshot: AlertsSnapshot)
}

extension SharedStore: StatusPersisting {}

enum StatusState: Equatable {
    enum Phase: Equatable {
        case idle
        case quiet
        case alarm
        case error
        case regionUnavailable
    }

    case idle
    case quiet(lastCheckedAt: Date)
    case alarm(lastCheckedAt: Date)
    case error
    case regionUnavailable

    var phase: Phase {
        switch self {
        case .idle:
            .idle
        case .quiet:
            .quiet
        case .alarm:
            .alarm
        case .error:
            .error
        case .regionUnavailable:
            .regionUnavailable
        }
    }

    var title: String {
        switch self {
        case .alarm:
            String(localized: "Alert Active")
        case .quiet:
            String(localized: "All Clear")
        case .idle:
            String(localized: "Checking…")
        case .error:
            String(localized: "Unavailable")
        case .regionUnavailable:
            String(localized: "Region Unavailable")
        }
    }

    var symbolName: String {
        switch self {
        case .alarm:
            "exclamationmark.circle.fill"
        case .quiet:
            "checkmark.circle.fill"
        case .idle:
            "arrow.triangle.2.circlepath"
        case .error, .regionUnavailable:
            "questionmark.circle.fill"
        }
    }

    var explanation: String {
        switch self {
        case .quiet:
            String(localized: "status.explanation.quiet")
        case .alarm:
            String(localized: "status.explanation.loud")
        case .idle:
            String(localized: "status.explanation.updating")
        case .error:
            String(localized: "status.explanation.unknown")
        case .regionUnavailable:
            String(localized: "status.explanation.region_unavailable")
        }
    }

    var detailText: String? {
        switch self {
        case let .alarm(lastCheckedAt), let .quiet(lastCheckedAt):
            String(format: String(localized: "Updated: %@"), lastCheckedAt.formatted(date: .omitted, time: .shortened))
        case .error:
            String(localized: "Tap Refresh to try again")
        case .regionUnavailable:
            String(localized: "status.detail.region_unavailable")
        case .idle:
            nil
        }
    }

    var checkedAt: Date? {
        switch self {
        case let .alarm(lastCheckedAt), let .quiet(lastCheckedAt):
            lastCheckedAt
        case .idle, .error, .regionUnavailable:
            nil
        }
    }
}

@MainActor
@Observable
final class StatusController {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Status")

    private(set) var state: StatusState = .idle
    private(set) var regionTitle: String
    private(set) var isLoading = false
    private(set) var lastSourceRaw: String?
    private(set) var lastSnapshot: AlertsSnapshot?
    private(set) var lastRefreshInterval: Duration?

    private var region: AlertRegion
    private let provider: any StatusProviding
    private let environmentProvider: any RefreshEnvironmentProviding
    private let persistence: any StatusPersisting
    private let widgetReloader: any WidgetReloading
    private let jitterUnitInterval: () -> Double
    private var periodicRefreshClients = 0
    private var periodicRefreshTask: Task<Void, Never>?
    private var powerStateObserver: NSObjectProtocol?
    private var suppressPollingUntil: Date?
    private let now: () -> Date

    init(
        region: AlertRegion,
        provider: any StatusProviding,
        environmentProvider: (any RefreshEnvironmentProviding)? = nil,
        persistence: any StatusPersisting,
        widgetReloader: any WidgetReloading,
        jitterUnitInterval: @escaping () -> Double = { Double.random(in: 0 ... 1) },
        now: @escaping () -> Date = { Date() }
    ) {
        self.region = region
        self.provider = provider
        self.environmentProvider = environmentProvider ?? SystemRefreshEnvironmentProvider()
        self.persistence = persistence
        self.widgetReloader = widgetReloader
        self.jitterUnitInterval = jitterUnitInterval
        self.now = now
        regionTitle = region.title
    }

    var currentRegion: AlertRegion {
        region
    }

    var isDataStale: Bool {
        guard let checkedAt = state.checkedAt else { return false }
        let interval = RefreshPolicy.baseIntervalSeconds(for: refreshEnvironment())
        return DataFreshness.isStale(
            checkedAt: checkedAt,
            now: now(),
            refreshIntervalSeconds: interval
        )
    }

    func refreshEnvironment() -> RefreshEnvironment {
        environmentProvider.current(isAlarmActive: state.phase == .alarm)
    }

    func nextRefreshInterval() -> Duration {
        RefreshPolicy.interval(for: refreshEnvironment(), jitterUnitInterval: jitterUnitInterval())
    }

    func setRegion(_ region: AlertRegion) {
        self.region = region
        regionTitle = region.title
        persistence.saveRegion(region)
        widgetReloader.reloadAllTimelines()
        applySnapshotToState()
        Task { await refresh() }
    }

    func beginPeriodicRefresh() {
        periodicRefreshClients += 1
        guard periodicRefreshTask == nil else { return }
        observePowerStateChanges()
        startPeriodicRefreshLoop()
    }

    func endPeriodicRefresh() {
        periodicRefreshClients = max(0, periodicRefreshClients - 1)
        guard periodicRefreshClients == 0 else { return }
        stopPeriodicRefreshLoop()
        if let powerStateObserver {
            NotificationCenter.default.removeObserver(powerStateObserver)
            self.powerStateObserver = nil
        }
    }

    private func startPeriodicRefreshLoop() {
        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = nextRefreshInterval()
                lastRefreshInterval = interval
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                await refresh(isScheduled: true)
            }
        }
    }

    private func stopPeriodicRefreshLoop() {
        periodicRefreshTask?.cancel()
        periodicRefreshTask = nil
    }

    private func observePowerStateChanges() {
        guard powerStateObserver == nil else { return }
        powerStateObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.periodicRefreshClients > 0 else { return }
                self.stopPeriodicRefreshLoop()
                self.startPeriodicRefreshLoop()
            }
        }
    }

    #if DEBUG
        func applyScreenshotFixture(_ phase: String) {
            let checkedAt = Date(timeIntervalSince1970: 1_720_000_000)
            switch phase {
            case "allClear":
                region = .kyivCity
                regionTitle = AlertRegion.kyivCity.title
                state = .quiet(lastCheckedAt: checkedAt)
            case "alertActive":
                region = .kharkiv
                regionTitle = AlertRegion.kharkiv.title
                state = .alarm(lastCheckedAt: checkedAt)
            case "checking":
                region = .kharkiv
                regionTitle = AlertRegion.kharkiv.title
                state = .idle
            case "unavailable":
                region = .kyivCity
                regionTitle = AlertRegion.kyivCity.title
                state = .error
            default:
                break
            }
        }
    #endif

    func refresh(isScheduled: Bool = false) async {
        if isScheduled, let until = suppressPollingUntil, now() < until {
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await provider.fetchAlerts()
            lastSnapshot = snapshot
            lastSourceRaw = snapshot.source
            suppressPollingUntil = nil
            persistence.saveSnapshot(snapshot)
            widgetReloader.reloadAllTimelines()
            applySnapshotToState()
        } catch let UbillingError.rateLimited(retryAfter) {
            suppressPollingUntil = retryAfter
            Self.log.error("Rate limited until \(retryAfter.timeIntervalSince1970, privacy: .public)")
            state = .error
        } catch {
            Self.log.error("Fetch status failed: \(String(describing: error), privacy: .public)")
            state = .error
        }
    }

    private func applySnapshotToState() {
        guard let snapshot = lastSnapshot else { return }
        if snapshot.status(for: region) == nil {
            let missingKey = region.apiKey
            Self.log.error("Region missing from snapshot: \(missingKey, privacy: .public)")
        }
        state = StatusStateResolver.resolve(snapshot: snapshot, region: region)
    }
}
