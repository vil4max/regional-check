import DriveCheckKit
import Foundation
import Observation

private enum MapImageError: Error {
    case badResponse
}

/// Feature state for the phone-only Map tab.
///
/// Owns the upstream raster download so SwiftUI views never touch networking.
/// Loads on its first appear in each phone foreground session and on explicit
/// refresh only — there is no polling, no prefetch, and no background work. A
/// generation counter keeps a late response for an obsolete variant from
/// overwriting newer state.
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

    private var variant: MapImageVariant = .day
    private var generation = 0
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

    /// The pull to refresh retries a map that failed, the one request "Refresh map" used to send
    /// before the failed card was hidden (UI-simplify AC-4); a loaded or never-loaded map is left
    /// alone, so the pull still never re-requests the raster (REQ-PROVIDER-002). It waits for the
    /// status fetch to settle and then `postStatusDelay`, as the automatic load does: the pull's
    /// own status request shares the host's rate limit.
    func retryIfFailed() {
        guard loadFailed, !isLoading else { return }
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
        loadTask = Task {
            do {
                if afterStatusSettles {
                    await self.statusSource.awaitStatusSettled()
                    try Task.checkCancellation()
                    try await self.sleep(Self.postStatusDelay)
                    try Task.checkCancellation()
                }
                let (data, response) = try await self.httpClient.data(from: url)
                try Task.checkCancellation()
                guard
                    let http = response as? HTTPURLResponse,
                    (200..<300).contains(http.statusCode),
                    !data.isEmpty
                else {
                    throw MapImageError.badResponse
                }
                guard current == self.generation else { return }
                self.imageData = data
                self.loadedAt = self.now()
                self.isLoading = false
            } catch is CancellationError {
                if current == self.generation {
                    self.isLoading = false
                }
            } catch {
                if current == self.generation {
                    self.isLoading = false
                    self.loadFailed = true
                }
            }
        }
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
    }
#endif
