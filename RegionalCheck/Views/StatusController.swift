import Foundation
import Observation
import os

enum StatusState: Equatable, Sendable {
    case idle
    case quiet(lastCheckedAt: Date)
    case alarm(lastCheckedAt: Date)
    case error

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
            return "speaker.wave.3.fill"
        case .quiet:
            return "speaker.slash.fill"
        case .idle:
            return "hourglass"
        case .error:
            return "questionmark.circle.fill"
        }
    }

    var detailText: String? {
        switch self {
        case .alarm(let lastCheckedAt), .quiet(let lastCheckedAt):
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

    init(
        region: AlertRegion,
        provider: any StatusProviding
    ) {
        self.region = region
        self.provider = provider
        self.regionTitle = region.title
    }

    func setRegion(_ region: AlertRegion) {
        self.region = region
        self.regionTitle = region.title
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snapshot = try await provider.fetchStatus(region: region)
            switch snapshot.status {
            case .alarm:
                state = .alarm(lastCheckedAt: snapshot.checkedAt)
            case .quiet:
                state = .quiet(lastCheckedAt: snapshot.checkedAt)
            }
        } catch {
            Self.log.error("Fetch status failed: \(String(describing: error), privacy: .public)")
            state = .error
        }
    }
}
