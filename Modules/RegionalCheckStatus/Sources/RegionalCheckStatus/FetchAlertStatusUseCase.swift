import Foundation
import RegionalCheckDomain

public struct FetchAlertStatusUseCase: Sendable {
    private let provider: any AirAlertProviding
    private let now: @Sendable () -> Date

    public init(provider: any AirAlertProviding, now: @escaping @Sendable () -> Date = Date.init) {
        self.provider = provider
        self.now = now
    }

    public func execute(region: AlertRegion) async throws -> AlertStatusSnapshot {
        let snapshot = try await provider.fetchStatus(region: region)
        return AlertStatusSnapshot(
            region: region,
            status: snapshot.status,
            checkedAt: now(),
            source: snapshot.source
        )
    }
}

