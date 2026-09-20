import CoreLocation
import DriveCheckKit
import Foundation
import Observation

/// What the CarPlay refresh cycle needs from location: the driving-task apps already narrow
/// via `HomeLocationSource`/`LocationSessionManaging`/`LocationFixProviding`, plus the two
/// fields those don't cover. `LocationManager` conforms unchanged (production behavior is the
/// same); a fake conforms it for tests, so `authorizationStatus` never depends on whatever a
/// given simulator's real location permission happens to be (was: RD-8b follow-up flake).
protocol CarPlayLocationSource: HomeLocationSource, LocationSessionManaging, LocationFixProviding {
    var authorizationStatus: CLAuthorizationStatus { get }
    var coordinateStamp: Int { get }
}

extension LocationManager: CarPlayLocationSource {}

/// Owns `CarPlayLoadState` and the CarPlay-initiated refresh cycle, so the scene
/// works on a CarPlay-only cold launch without the phone scene ever activating.
@MainActor
@Observable
final class CarPlayRefreshCoordinator {
    static let maxAttempts = 3
    /// 8 × the 5 s settle timeout = 40 s, just past the longest single request (15 + 2 + 15 s).
    private static let maxInFlightWaits = 8
    static let locationWaitTimeout: Duration = .seconds(5)
    private static let locationPollInterval: Duration = .milliseconds(250)

    private(set) var loadState: CarPlayLoadState

    @ObservationIgnored private let status: StatusController
    @ObservationIgnored private let location: any CarPlayLocationSource
    @ObservationIgnored private let regions: RegionSelection
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let backoffSleep: (Duration) async throws -> Void
    @ObservationIgnored private let locationPollSleep: (Duration) async throws -> Void
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var cycle = 0

    init(
        status: StatusController,
        location: any CarPlayLocationSource,
        regions: RegionSelection,
        now: @escaping () -> Date = { Date() },
        backoffSleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        locationPollSleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.status = status
        self.location = location
        self.regions = regions
        self.now = now
        self.backoffSleep = backoffSleep
        self.locationPollSleep = locationPollSleep
        loadState = .loading(cached: Self.cachedSnapshot(from: status))
    }

    static func cachedSnapshot(from status: StatusController) -> CarPlaySnapshot? {
        guard let snapshot = status.lastSnapshot else { return nil }
        return CarPlaySnapshot(
            state: StatusStateResolver.resolve(snapshot: snapshot, region: status.currentRegion),
            regionTitle: status.regionTitle,
            checkedAt: snapshot.checkedAt
        )
    }

    static func backoff(afterAttempt attempt: Int) -> Duration {
        .seconds(2 << (attempt - 1))
    }

    func freshness() -> CarPlayFreshness {
        CarPlayFreshness(
            now: now(),
            refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: status.refreshEnvironment())
        )
    }

    /// Supersedes any running cycle and shows `loading` immediately.
    @discardableResult
    func refresh(reason: String) -> Task<Void, Never> {
        refreshTask?.cancel()
        cycle += 1
        let cycle = cycle
        setLoadState(.loading(cached: Self.cachedSnapshot(from: status)))
        CarPlayLog.lifecycle.info("Refresh cycle \(cycle, privacy: .public) started: \(reason, privacy: .public)")
        let task = Task { [weak self] in
            guard let self else { return }
            await run(cycle: cycle)
        }
        refreshTask = task
        return task
    }

    func cancel() {
        refreshTask?.cancel()
        refreshTask = nil
        cycle += 1
        // The cancelled cycle fails `isCurrent` and returns without a terminal state, and no
        // newer cycle exists to set one. Settle here, or `.loading` — and the Status template's
        // "Checking…" button that reads it — outlives the request that set it.
        settleFromStatus()
    }

    /// Ends `.loading` with whatever `StatusController` currently knows.
    private func settleFromStatus() {
        guard loadState.isLoading else { return }
        let cached = Self.cachedSnapshot(from: status)
        if !status.hasRefreshFailed, let cached {
            setLoadState(.loaded(cached))
        } else {
            setLoadState(.failed(cached: cached))
        }
    }

    /// Mirrors refreshes the coordinator did not start (periodic timer, phone UI,
    /// region change) while keeping an active CarPlay cycle in `loading`.
    func synchronizeWithStatus() {
        let cached = Self.cachedSnapshot(from: status)
        switch loadState {
        case .loading:
            setLoadState(.loading(cached: cached))
        case .loaded, .failed:
            if !status.hasRefreshFailed, let cached {
                setLoadState(.loaded(cached))
            } else {
                setLoadState(.failed(cached: cached))
            }
        }
    }

    private func run(cycle: Int) async {
        async let regionWait: Void = waitForFirstLocation()
        let succeeded = await fetchWithRetries(cycle: cycle)
        await regionWait
        guard isCurrent(cycle) else {
            // Superseded: the newer cycle owns the state. Merely cancelled, with the cycle number
            // unchanged: nobody else will finish it, so it must not stay in `.loading`.
            if cycle == self.cycle {
                settleFromStatus()
            }
            return
        }
        let cached = Self.cachedSnapshot(from: status)
        if succeeded, let cached {
            setLoadState(.loaded(cached))
        } else {
            setLoadState(.failed(cached: cached))
        }
        let outcome = loadState.logDescription
        CarPlayLog.lifecycle.info("Refresh cycle \(cycle, privacy: .public) finished: \(outcome, privacy: .public)")
    }

    private func fetchWithRetries(cycle: Int) async -> Bool {
        for attempt in 1 ... Self.maxAttempts {
            guard isCurrent(cycle) else { return false }
            CarPlayLog.lifecycle
                .info("Request start: cycle=\(cycle, privacy: .public) attempt=\(attempt, privacy: .public)")
            await performAttempt()
            guard isCurrent(cycle) else {
                CarPlayLog.lifecycle.info("Request superseded: cycle=\(cycle, privacy: .public)")
                return false
            }
            if !status.hasRefreshFailed {
                CarPlayLog.lifecycle
                    .info("Request end: cycle=\(cycle, privacy: .public) attempt=\(attempt, privacy: .public)")
                return true
            }
            let isRateLimited = status.isRateLimited
            CarPlayLog.lifecycle.error(
                """
                Request error: cycle=\(cycle, privacy: .public) attempt=\(attempt, privacy: .public) \
                rateLimited=\(isRateLimited, privacy: .public)
                """
            )
            guard attempt < Self.maxAttempts, !isRateLimited else { return false }
            do {
                try await backoffSleep(Self.backoff(afterAttempt: attempt))
            } catch {
                return false
            }
        }
        return false
    }

    private func performAttempt() async {
        if status.isLoading {
            // Join a refresh already in flight instead of issuing a parallel request.
            // Bounded: `awaitStatusSettled()` also resumes on its own 5 s timeout with `isLoading`
            // still true, so an unbounded loop re-suspended for as long as the phone kept a refresh
            // in flight. One request is at most a 15 s timeout, a 2 s retry delay and another 15 s.
            var waits = 0
            while status.isLoading, !Task.isCancelled, waits < Self.maxInFlightWaits {
                await status.awaitStatusSettled()
                waits += 1
            }
            return
        }
        // Unstructured on purpose: cancelling a superseded CarPlay cycle must not cancel
        // the shared URLSession request and mark `StatusController` failed for the phone.
        await Task { [status] in
            await status.refresh()
        }.value
    }

    /// Bounded wait so the first loaded snapshot uses the location-derived region;
    /// on timeout the persisted region from the previous session stays in effect.
    private func waitForFirstLocation() async {
        guard regions.followsLocation, location.lastFix == nil else { return }
        guard [.authorizedWhenInUse, .authorizedAlways].contains(location.authorizationStatus) else { return }
        var waited: Duration = .zero
        while location.lastFix == nil, waited < Self.locationWaitTimeout {
            do {
                try await locationPollSleep(Self.locationPollInterval)
            } catch {
                return
            }
            waited += Self.locationPollInterval
        }
        if location.lastFix == nil {
            CarPlayLog.lifecycle.info("Location wait timed out; using persisted region")
        }
    }

    private func isCurrent(_ cycle: Int) -> Bool {
        !Task.isCancelled && cycle == self.cycle
    }

    private func setLoadState(_ newValue: CarPlayLoadState) {
        guard newValue != loadState else { return }
        loadState = newValue
    }
}
