import DriveCheckKit
import Foundation
import Observation
import os

@MainActor
protocol StatusPersisting {
    func saveRegion(_ region: AlertRegion)
    func saveSnapshot(_ snapshot: AlertsSnapshot)
    func loadSnapshot() -> AlertsSnapshot?
}

extension SharedStore: StatusPersisting {}

@MainActor
@Observable
final class StatusController {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Status")

    private(set) var firstKnownStatusAt: ContinuousClock.Instant?
    private(set) var state: StatusState = .idle
    private(set) var regionTitle: String
    private(set) var isLoading = false
    private(set) var hasRefreshFailed = false
    private(set) var lastSourceRaw: String?
    private(set) var lastSnapshot: AlertsSnapshot?
    private(set) var lastRefreshInterval: Duration?
    private(set) var statusDetailsRevision: Int?

    private var region: AlertRegion
    private var hasAttemptedRefresh = false
    private var statusSettledWaiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private let provider: any StatusProviding
    private let environmentProvider: any RefreshEnvironmentProviding
    private let persistence: any StatusPersisting
    private let widgetReloader: any WidgetReloading
    private let jitterUnitInterval: () -> Double
    private var periodicRefreshClients = 0
    private var periodicRefreshTask: Task<Void, Never>?
    private var powerStateObserver: NSObjectProtocol?
    private var suppressPollingUntil: Date?
    private var refreshRevision = 0
    /// Minimum spacing between network fetches (REQ-REFRESH-010). Above the provider's 3 s server
    /// cache, inside which a refetch returns identical data, and below the 27 s a scheduled alarm
    /// poll can reach after jitter, so the floor never swallows a scheduled poll.
    static let fetchFloor: TimeInterval = 10
    private var lastSuccessfulFetchAt: Date?
    private let now: () -> Date
    private let statusSettledTimeout: Duration

    init(
        region: AlertRegion,
        provider: any StatusProviding,
        environmentProvider: (any RefreshEnvironmentProviding)? = nil,
        persistence: any StatusPersisting,
        widgetReloader: any WidgetReloading,
        jitterUnitInterval: @escaping () -> Double = { Double.random(in: 0 ... 1) },
        now: @escaping () -> Date = { Date() },
        statusSettledTimeout: Duration = .seconds(5)
    ) {
        self.region = region
        self.provider = provider
        self.environmentProvider = environmentProvider ?? SystemRefreshEnvironmentProvider()
        self.persistence = persistence
        self.widgetReloader = widgetReloader
        self.jitterUnitInterval = jitterUnitInterval
        self.now = now
        self.statusSettledTimeout = statusSettledTimeout
        regionTitle = region.title
        lastSnapshot = persistence.loadSnapshot()
        statusDetailsRevision = lastSnapshot == nil ? nil : refreshRevision
        applySnapshotToState()
        if state.phase != .idle {
            firstKnownStatusAt = .now
        }
        #if DEBUG
            if state.phase != .idle {
                ColdStartTrace.record("cached-status-known")
            }
        #endif
    }

    var currentRegion: AlertRegion {
        region
    }

    /// See `RegionStatusSource.awaitStatusSettled()`. Bounded by
    /// `statusSettledTimeout` so a caller never hangs when no refresh comes
    /// (e.g. previews/fixtures that skip `MainTabViewModel.appear()`).
    /// The waiter registers synchronously on the main actor before suspending,
    /// so a refresh settling in between cannot be missed; the timeout and
    /// cancellation resume it by id, and each continuation resumes once.
    func awaitStatusSettled() async {
        let alreadySettled = !isLoading && (hasAttemptedRefresh || lastSnapshot != nil)
        guard !alreadySettled else { return }
        let id = UUID()
        let timeout = Task { [weak self, statusSettledTimeout] in
            try? await Task.sleep(for: statusSettledTimeout)
            self?.resumeStatusSettledWaiter(id)
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                statusSettledWaiters[id] = continuation
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resumeStatusSettledWaiter(id)
            }
        }
        timeout.cancel()
    }

    private func resumeStatusSettledWaiter(_ id: UUID) {
        statusSettledWaiters.removeValue(forKey: id)?.resume()
    }

    var lastKnownState: StatusState? {
        guard let lastSnapshot, lastSnapshot.status(for: region) != nil else { return nil }
        return StatusStateResolver.resolve(snapshot: lastSnapshot, region: region)
    }

    var isDataStale: Bool {
        if hasRefreshFailed {
            return true
        }
        guard let checkedAt = state.checkedAt else { return false }
        let interval = RefreshPolicy.baseIntervalSeconds(for: refreshEnvironment())
        return DataFreshness.isStale(
            checkedAt: checkedAt,
            now: now(),
            refreshIntervalSeconds: interval
        )
    }

    var isRateLimited: Bool {
        guard let suppressPollingUntil else { return false }
        return now() < suppressPollingUntil
    }

    func refreshEnvironment() -> RefreshEnvironment {
        environmentProvider.current(isAlarmActive: state.phase == .alarm)
    }

    func nextRefreshInterval() -> Duration {
        RefreshPolicy.interval(for: refreshEnvironment(), jitterUnitInterval: jitterUnitInterval())
    }

    func setRegion(_ region: AlertRegion) {
        guard self.region != region else { return }
        self.region = region
        regionTitle = region.title
        persistence.saveRegion(region)
        widgetReloader.reloadAllTimelines()
        applySnapshotToState()
        Task { await refresh() }
    }

    /// Readable so a test can assert REQ-REFRESH-002's ref count; every part of it was private.
    var isPeriodicRefreshRunning: Bool {
        periodicRefreshTask != nil
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
            // A frozen past timestamp reads as stale against the real wall clock the
            // freshness check runs on, showing "Data may be outdated" on a screenshot
            // meant to look current. Use the controller's own clock instead.
            let checkedAt = now()
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

    /// Whether this refresh must complete without a request.
    ///
    /// Two independent holds. A rate-limit window skips *scheduled* polls only (REQ-REFRESH-005).
    /// The fetch floor holds every trigger (REQ-REFRESH-010): the held snapshot stays as it is and
    /// neither a failure nor staleness is recorded. It is measured from the last success — only
    /// then is there a fresh answer to serve, and retries after a failure keep the spacing
    /// REQ-REFRESH-003/004/005 give them (CarPlay's 2 s and 4 s attempts would otherwise be
    /// swallowed). `nil` keeps a session's first fetch immediate.
    private func isFetchHeld(isScheduled: Bool) -> Bool {
        if isScheduled, let until = suppressPollingUntil, now() < until {
            return true
        }
        if let lastSuccessfulFetchAt, now().timeIntervalSince(lastSuccessfulFetchAt) < Self.fetchFloor {
            return true
        }
        return false
    }

    /// Never a second request while one is in flight. A scheduled poll returns at once so the
    /// timer loop cannot pile up behind a slow request; a driver's pull waits for the request
    /// already running, because returning immediately snaps the pull spinner back with nothing to
    /// show — and during an alarm a poll is in flight most of the time.
    private func defersToInFlightRefresh(isScheduled: Bool) async -> Bool {
        guard isLoading else { return false }
        if !isScheduled {
            await awaitStatusSettled()
        }
        return true
    }

    func refresh(isScheduled: Bool = false) async {
        guard !isFetchHeld(isScheduled: isScheduled) else { return }
        if await defersToInFlightRefresh(isScheduled: isScheduled) {
            return
        }
        refreshRevision += 1
        statusDetailsRevision = nil
        isLoading = true
        defer {
            isLoading = false
            hasAttemptedRefresh = true
            if firstKnownStatusAt == nil, state.phase != .idle {
                firstKnownStatusAt = .now
            }
            #if DEBUG
                if state.phase != .idle {
                    ColdStartTrace.record("status-settled")
                }
            #endif
            let waiters = statusSettledWaiters.values
            statusSettledWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
        do {
            let snapshot = try await provider.fetchAlerts()
            applyFetched(snapshot, isScheduled: isScheduled)
        } catch let UbillingError.rateLimited(retryAfter) {
            hasRefreshFailed = true
            suppressPollingUntil = retryAfter
            Self.log.error("Rate limited until \(retryAfter.timeIntervalSince1970, privacy: .public)")
            if lastSnapshot == nil {
                state = .error
            }
        } catch where Self.isCancellation(error) {
            // A withdrawn request is not a failed one. `HomeView`'s `.task(id: scenePhase)` cancels
            // on every scene change — the location prompt, Control Centre, a quick background —
            // and recording that as a failure marked seconds-old data stale. The held snapshot
            // and the previous failure flag both stay exactly as they were.
            Self.log.info("Fetch status cancelled")
        } catch {
            hasRefreshFailed = true
            Self.log.error("Fetch status failed: \(String(describing: error), privacy: .public)")
            if lastSnapshot == nil {
                state = .error
            }
        }
    }

    private func applyFetched(_ snapshot: AlertsSnapshot, isScheduled: Bool) {
        let previous = persistence.loadSnapshot()
        let widgetContentChanged = previous?.checkedAt != snapshot.checkedAt
            || previous?.statuses != snapshot.statuses
            || previous?.source != snapshot.source
        hasRefreshFailed = false
        lastSuccessfulFetchAt = now()
        lastSnapshot = snapshot
        lastSourceRaw = snapshot.source
        suppressPollingUntil = nil
        persistence.saveSnapshot(snapshot)
        // Re-fetching the same server cache doesn't change the widgets or their expiry timeline.
        if !isScheduled || widgetContentChanged {
            widgetReloader.reloadAllTimelines()
        }
        applySnapshotToState()
        statusDetailsRevision = refreshRevision
        let env = refreshEnvironment()
        let intervalSec = Int(RefreshPolicy.baseIntervalSeconds(for: env))
        Self.log.info(
            """
            Status refresh OK: scheduled=\(isScheduled, privacy: .public), \
            interval=\(intervalSec, privacy: .public)s, \
            expensive=\(env.isExpensiveNetwork, privacy: .public), \
            constrained=\(env.isConstrainedNetwork, privacy: .public)
            """
        )
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
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
