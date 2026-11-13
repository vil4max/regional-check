import DriveCheckKit
import Foundation
import Observation

private enum MapImageError: Error {
    case badResponse
}

/// A map request that has left for upstream, with the alarm set it was taken under.
private struct InFlightRequest {
    let alarmSet: Set<AlertRegion>?
}

/// Feature state for the phone-only Map tab.
///
/// Owns the upstream raster download so SwiftUI views never touch networking.
/// Loads on its first appear in each phone foreground session, after a pull that fetched a
/// status, and when an accepted snapshot changes the set of regions in alarm (MAP-sync) — there
/// is no map timer, no prefetch, and no background work. Each image remembers the alarm set it was
/// loaded under, so the card never shows a picture that disagrees with the status above it. A
/// generation counter keeps a late response for an obsolete request from overwriting newer state.
@MainActor
@Observable
final class MapViewModel {
    /// The upstream host shares one rate limit between the alert-status JSON
    /// endpoint and this map-image endpoint: two requests landing in the
    /// same instant get one of them a 429. This is the buffer left after the
    /// status fetch settles before the first automatic map request fires.
    /// 3 s, not the earlier 1.5 s: on some launches the map still failed and
    /// stayed unloaded until a manual refresh.
    static let postStatusDelay: Duration = .seconds(3)

    private let statusSource: any RegionStatusSource
    private let httpClient: any HTTPClient
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void

    private(set) var imageData: Data?
    private(set) var loadedAt: Date?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    /// The regions in alarm when the image on hand was requested; `nil` when no snapshot existed.
    private var imageAlarmSet: Set<AlertRegion>?
    private var variant: MapImageVariant = .day
    private var generation = 0
    /// The set a request already sent was taken under; `nil` while no request has left yet (the load
    /// still waits for the status), so a status change then needs no new load.
    @ObservationIgnored
    private var inFlight: InFlightRequest?
    /// The image or failure on hand belongs to an ended foreground session; the next `appear()`
    /// replaces it with this session's own load.
    @ObservationIgnored
    private var sessionEnded = false
    /// Task.cancel() is thread-safe; the handle is only ever replaced on MainActor.
    /// @ObservationIgnored so the @Observable macro leaves this as a plain stored
    /// property — otherwise its generated accessors make nonisolated(unsafe) a no-op.
    @ObservationIgnored
    private nonisolated(unsafe) var loadTask: Task<Void, Never>?

    init(
        statusSource: any RegionStatusSource,
        httpClient: any HTTPClient,
        now: @escaping () -> Date = { Date() },
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.statusSource = statusSource
        self.httpClient = httpClient
        self.now = now
        self.sleep = sleep
        followStatus()
    }

    deinit {
        loadTask?.cancel()
    }

    var accessibilityLabel: String {
        mapAccessibilityLabel(snapshot: statusSource.lastSnapshot)
    }

    /// Loads once per foreground session: after a failed load only a pull to refresh retries,
    /// so the shared host limit is not spent each time the card scrolls back into view.
    func appear() {
        guard !isLoading else { return }
        if sessionEnded {
            // A new session starts like the first one, on the placeholder: the previous session's
            // raster can be hours older than the status this session has just fetched.
            imageData = nil
            loadedAt = nil
            loadFailed = false
        }
        guard imageData == nil, !loadFailed else { return }
        startLoad(afterStatusSettles: true)
    }

    /// The phone's foreground session ended. The process can stay alive in the background for
    /// hours, so the map is fetched once per foreground session, like the status, not per process.
    func endForegroundSession() {
        sessionEnded = true
    }

    func refresh() {
        guard !isLoading else { return }
        startLoad(afterStatusSettles: false)
    }

    /// The pull to refresh. When its own status request returned a new snapshot, a loaded or
    /// failed map reloads (MAP-sync AC-2), keeping a same-set image on screen until the new one
    /// lands. When the pull fetched nothing (the REQ-REFRESH-010 floor, a failure, a rate limit)
    /// only a failed map is retried, the one request "Refresh map" used to send (UI-simplify AC-4),
    /// so a map request always follows a status request. A never-loaded map is left to `appear()`,
    /// and a load already running (a status change got there first) is not doubled. The reload
    /// waits for the status to settle and `postStatusDelay`: both share the host's rate limit.
    func refreshFromPull(statusWasFetched: Bool) {
        guard !isLoading else { return }
        if statusWasFetched {
            guard imageData != nil || loadFailed else { return }
        } else {
            guard loadFailed else { return }
        }
        startLoad(afterStatusSettles: true)
    }

    func disappear() {
        loadTask?.cancel()
    }

    func setVariant(_ newVariant: MapImageVariant) {
        guard newVariant != variant else { return }
        variant = newVariant
        guard imageData != nil, !isLoading else { return }
        startLoad(afterStatusSettles: false)
    }

    /// `afterStatusSettles` only applies to the first automatic load on
    /// appear, where it races the alert-status fetch for the same host.
    /// Manual refresh and variant reloads happen well clear of that window.
    private func startLoad(afterStatusSettles: Bool) {
        loadTask?.cancel()
        generation += 1
        let current = generation
        let url = MapImageSource.url(for: variant)
        isLoading = true
        loadFailed = false
        sessionEnded = false
        inFlight = nil
        loadTask = Task {
            do {
                if afterStatusSettles {
                    await self.statusSource.awaitStatusSettled()
                    try Task.checkCancellation()
                    try await self.sleep(Self.postStatusDelay)
                    try Task.checkCancellation()
                }
                let alarmSet = self.currentAlarmSet
                self.inFlight = InFlightRequest(alarmSet: alarmSet)
                let data = try await self.fetchImage(from: url)
                guard current == self.generation else { return }
                self.imageData = data
                self.imageAlarmSet = alarmSet
                self.loadedAt = self.now()
                self.finishLoad()
            } catch is CancellationError {
                if current == self.generation {
                    self.finishLoad()
                }
            } catch {
                if current == self.generation {
                    self.finishLoad()
                    self.loadFailed = true
                }
            }
        }
    }

    private func finishLoad() {
        isLoading = false
        inFlight = nil
    }
}

// MARK: - Following the status (MAP-sync)

extension MapViewModel {
    /// The image the card may show: only one loaded under the alarm set of the current status, so
    /// the old picture is gone the moment the status moves, before any reload starts (MAP-sync AC-3).
    var visibleImageData: Data? {
        guard !loadFailed, imageAlarmSet == currentAlarmSet else { return nil }
        return imageData
    }

    /// When the shown map was loaded (MAP-sync AC-7). Upstream sometimes serves an older raster than
    /// its JSON; the owner chose to state the map's own time rather than check the picture.
    var updatedCaption: String? {
        guard visibleImageData != nil, let loadedAt else { return nil }
        let time = loadedAt.formatted(date: .omitted, time: .shortened)
        return String(format: String(localized: "map.caption.updated"), time)
    }

    private var currentAlarmSet: Set<AlertRegion>? {
        statusSource.lastSnapshot.map(mapAlarmRegions(in:))
    }

    /// Reloads the map once an accepted snapshot changes the set of regions in alarm, for a map
    /// loaded or loading in the live phone session. A never-loaded, failed or ended-session map is
    /// left to its own triggers: this rides the shared status poll and must not add map requests
    /// for CarPlay-only or background polls (REQ-PROVIDER-002, amended 2026-11-12).
    func statusDidChange() {
        guard !sessionEnded else { return }
        let current = currentAlarmSet
        if isLoading {
            guard let inFlight, inFlight.alarmSet != current else { return }
        } else {
            guard imageData != nil, !loadFailed, imageAlarmSet != current else { return }
        }
        imageData = nil
        loadedAt = nil
        startLoad(afterStatusSettles: true)
    }

    /// Follows the status for the life of the model, from `init`. A source that is not observable
    /// (a test stub) never fires it; tests then call `statusDidChange()` themselves.
    fileprivate func followStatus() {
        withObservationTracking {
            _ = currentAlarmSet
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.statusDidChange()
                self?.followStatus()
            }
        }
    }

    /// Upstream sends `max-age=60` with no validators: a cached raster could be a minute older than
    /// the status it is meant to match, so every request bypasses the local cache (MAP-sync AC-4).
    private func fetchImage(from url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await httpClient.data(for: request)
        try Task.checkCancellation()
        guard
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode),
            !data.isEmpty
        else {
            throw MapImageError.badResponse
        }
        return data
    }
}

#if DEBUG
    extension MapViewModel {
        /// A model that already holds a loaded image, for previews and Prefire snapshots.
        ///
        /// `appear()` starts an async load that awaits the status settling and then an HTTP hop, so
        /// a snapshot captured after the template's settle delay shows whichever of the placeholder,
        /// the spinner or the image that machine happened to reach first. Building the settled state
        /// directly removes the race; `imageData` stays `private(set)` for everything that ships.
        ///
        /// `variant` must match whatever color scheme the preview actually renders under: `MapCardView`
        /// calls `setVariant` from `.onAppear`/`.onChange(of: colorScheme)`, and `setVariant` starts a
        /// real load whenever the incoming variant differs from this model's — the same race preloading
        /// the image was built to remove. Left at the model's own `.day` default, a preview that renders
        /// dark (the app's `.preferredColorScheme(.dark)`, or a recording machine whose default preview
        /// appearance is dark) computes `.night`, which differs, and reloads.
        static func preloaded(
            imageData: Data,
            loadedAt: Date,
            statusSource: any RegionStatusSource,
            httpClient: any HTTPClient,
            variant: MapImageVariant = .day
        ) -> MapViewModel {
            let model = MapViewModel(
                statusSource: statusSource,
                httpClient: httpClient,
                now: { loadedAt },
                sleep: { _ in }
            )
            model.imageData = imageData
            model.imageAlarmSet = statusSource.lastSnapshot.map(mapAlarmRegions(in:))
            model.loadedAt = loadedAt
            model.variant = variant
            return model
        }

        /// RD-6: a model frozen mid-load, for the full-screen cover's loading-state preview and
        /// snapshot — `refresh()`'s own async task has the same capture race `preloaded` removes
        /// for the loaded state.
        static func loadingPreview(statusSource: any RegionStatusSource, httpClient: any HTTPClient) -> MapViewModel {
            let model = MapViewModel(statusSource: statusSource, httpClient: httpClient, sleep: { _ in })
            model.isLoading = true
            return model
        }

        /// STATUS-reason AC-4: a model whose load failed, so the Status preview shows the hidden map
        /// and the region-list row standing in for it. `variant` as in `preloaded`.
        static func failedPreview(
            statusSource: any RegionStatusSource,
            httpClient: any HTTPClient,
            variant: MapImageVariant = .day
        ) -> MapViewModel {
            let model = MapViewModel(statusSource: statusSource, httpClient: httpClient, sleep: { _ in })
            model.loadFailed = true
            model.variant = variant
            return model
        }
    }
#endif
