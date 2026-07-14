import Foundation
import Observation
import os

enum StatusState: Equatable, Sendable {
    case idle
    case quiet(lastCheckedAt: Date, source: String)
    case alarm(lastCheckedAt: Date, source: String)
    case error(message: String)

    var title: String {
        switch self {
        case .alarm:
            return String(localized: "Loud")
        case .quiet:
            return String(localized: "Quiet")
        case .idle:
            return String(localized: "Checking…")
        case .error:
            return String(localized: "Unknown")
        }
    }

    var symbolName: String {
        switch self {
        case .alarm:
            return "circle.fill"
        case .quiet:
            return "checkmark.circle.fill"
        case .idle:
            return "ellipsis.circle"
        case .error:
            return "arrow.clockwise.circle"
        }
    }

    var detailText: String? {
        switch self {
        case .alarm(let lastCheckedAt, _), .quiet(let lastCheckedAt, _):
            return String(format: String(localized: "Updated: %@"), lastCheckedAt.formatted(date: .omitted, time: .shortened))
        case .error:
            return String(localized: "Tap Refresh to try again")
        case .idle:
            return nil
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

    private var region: AlertRegion
    private let provider: any StatusProviding
    private let now: @Sendable () -> Date

    init(
        region: AlertRegion,
        provider: any StatusProviding,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.region = region
        self.provider = provider
        self.now = now
        self.regionTitle = region.title
    }

    func setRegion(_ region: AlertRegion) {
        self.region = region
        self.regionTitle = region.title
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let snapshot = try await provider.fetchStatus(region: region)
                let checkedAt = now()
                switch snapshot.status {
                case .alarm:
                    state = .alarm(lastCheckedAt: checkedAt, source: snapshot.source)
                case .quiet:
                    state = .quiet(lastCheckedAt: checkedAt, source: snapshot.source)
                }
            } catch {
                Self.log.error("Fetch status failed: \(error.localizedDescription, privacy: .public)")
                state = .error(message: String(localized: "Unknown"))
            }
        }
    }
}
