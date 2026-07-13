import Foundation

public struct AlertRegion: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case kyivCity
        case oblast(name: String)
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }

    public static let kyivCity = AlertRegion(kind: .kyivCity)
}

public enum AlertStatus: Equatable, Sendable {
    case quiet
    case alarm
}

public struct AlertStatusSnapshot: Equatable, Sendable {
    public let region: AlertRegion
    public let status: AlertStatus
    public let checkedAt: Date
    public let source: String

    public init(region: AlertRegion, status: AlertStatus, checkedAt: Date, source: String) {
        self.region = region
        self.status = status
        self.checkedAt = checkedAt
        self.source = source
    }
}

public protocol AirAlertProviding: Sendable {
    func fetchStatus(region: AlertRegion) async throws -> AlertStatusSnapshot
    func fetchAllOblastStatuses() async throws -> [AlertStatusSnapshot]
}

