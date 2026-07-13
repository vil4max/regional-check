import Foundation
import Observation
import os

enum StatusState: Equatable, Sendable {
    case idle
    case quiet(lastCheckedAt: Date, source: String)
    case alarm(lastCheckedAt: Date, source: String)
    case error(message: String)
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
                state = .error(message: String(localized: "Unable to update"))
            }
        }
    }
}
