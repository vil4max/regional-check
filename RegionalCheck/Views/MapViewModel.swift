import DriveCheckKit
import Foundation
import Observation

private enum MapImageError: Error {
    case badResponse
}

/// Feature state for the phone-only Map tab.
///
/// Owns the upstream raster download so SwiftUI views never touch networking.
/// Loads on first appear and on explicit refresh only — there is no polling,
/// no prefetch, and no background work. A generation counter keeps a late
/// response for an obsolete variant from overwriting newer state.
@MainActor
@Observable
final class MapViewModel {
    /// The upstream host shares one rate limit between the alert-status JSON
    /// endpoint and this map-image endpoint: two requests landing in the
    /// same instant get one of them a 429. This is the buffer left after the
    /// status fetch settles before the first automatic map request fires.
    /// 3 s, not the earlier 1.5 s: on some launches the map still failed and
    /// stayed unloaded until a manual refresh (owner, 2026-09-21).
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

    /// "N min ago" / "N h ago" from the image's own fetch time — never `checkedAt`, so a stale
    /// alert snapshot never dresses up the map's own age (RD-6 failure condition).
    var ageText: String? {
        loadedAt.map { Self.relativeAge(since: $0, now: now()) }
    }

    /// RD-6 full-screen caption: "N of 25 regions under alert · {ageText}" (`states.md` row 6a).
    /// `nil` before the first successful load — the row alone should not compute or show a count.
    var fullscreenCaption: String? {
        guard let ageText, let snapshot = statusSource.lastSnapshot else { return nil }
        let total = AlertRegion.allCases.count
        let alarmCount = snapshot.statuses.values.filter { $0 == .alarm }.count
        return String(format: String(localized: "map.fullscreen.caption"), alarmCount, total, ageText)
    }

    /// Reuses CarPlay's own "N min/h ago" keys rather than adding a byte-identical pair: same
    /// concept, same abbreviated wording in en/ru/uk (`CarPlayFreshness.ageText(since:)`).
    private static func relativeAge(since date: Date, now: Date) -> String {
        let minutes = max(1, Int(now.timeIntervalSince(date) / 60))
        if minutes < 60 {
            return String(format: String(localized: "driver.age.minutes"), minutes)
        }
        return String(format: String(localized: "driver.age.hours"), minutes / 60)
    }

    func appear() {
        guard imageData == nil, !isLoading else { return }
        startLoad(afterStatusSettles: true)
    }

    func refresh() {
        guard !isLoading else { return }
        startLoad(afterStatusSettles: false)
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
                    (200 ..< 300).contains(http.statusCode),
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

        /// RD-6: a model frozen in the failed state, for the full-screen cover's failed-state
        /// preview and snapshot — same race as `loadingPreview`.
        static func failedPreview(statusSource: any RegionStatusSource, httpClient: any HTTPClient) -> MapViewModel {
            let model = MapViewModel(statusSource: statusSource, httpClient: httpClient, sleep: { _ in })
            model.loadFailed = true
            return model
        }
    }
#endif
