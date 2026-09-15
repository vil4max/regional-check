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
    private let statusSource: any RegionStatusSource
    private let httpClient: any HTTPClient
    private let now: () -> Date

    private(set) var imageData: Data?
    private(set) var loadedAt: Date?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    private var variant: MapImageVariant = .day
    private var generation = 0
    /// Task.cancel() is thread-safe; the handle is only ever replaced on MainActor.
    private nonisolated(unsafe) var loadTask: Task<Void, Never>?

    init(
        statusSource: any RegionStatusSource,
        httpClient: any HTTPClient,
        now: @escaping () -> Date = { Date() }
    ) {
        self.statusSource = statusSource
        self.httpClient = httpClient
        self.now = now
    }

    deinit {
        loadTask?.cancel()
    }

    var accessibilityLabel: String {
        mapAccessibilityLabel(snapshot: statusSource.lastSnapshot)
    }

    var ageText: String? {
        loadedAt.map {
            String(
                format: String(localized: "Updated: %@"),
                $0.formatted(date: .omitted, time: .shortened)
            )
        }
    }

    func appear() {
        guard imageData == nil, !isLoading else { return }
        startLoad()
    }

    func refresh() {
        guard !isLoading else { return }
        startLoad()
    }

    func disappear() {
        loadTask?.cancel()
    }

    func setVariant(_ newVariant: MapImageVariant) {
        guard newVariant != variant else { return }
        variant = newVariant
        guard imageData != nil, !isLoading else { return }
        startLoad()
    }

    private func startLoad() {
        loadTask?.cancel()
        generation += 1
        let current = generation
        let url = MapImageSource.url(for: variant)
        isLoading = true
        loadFailed = false
        loadTask = Task {
            do {
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
