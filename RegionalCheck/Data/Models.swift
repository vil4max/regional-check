import Foundation

struct AlertRegion: Hashable, Sendable, Codable {
    enum Kind: Hashable, Sendable, Codable {
        case kyivCity
        case oblast(name: String)
    }

    let kind: Kind

    init(kind: Kind) {
        self.kind = kind
    }

    static let kyivCity = AlertRegion(kind: .kyivCity)

    var title: String {
        switch kind {
        case .kyivCity:
            return "Kyiv"
        case .oblast(let name):
            return name
        }
    }
}

enum AlertStatus: Equatable, Sendable {
    case quiet
    case alarm
}

struct AlertStatusSnapshot: Equatable, Sendable {
    let region: AlertRegion
    let status: AlertStatus
    let checkedAt: Date
    let source: String
}

protocol StatusProviding: Sendable {
    func fetchStatus(region: AlertRegion) async throws -> AlertStatusSnapshot
}
