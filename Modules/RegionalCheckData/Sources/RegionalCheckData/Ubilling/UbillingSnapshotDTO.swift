import Foundation

struct UbillingSnapshotDTO: Decodable, Sendable {
    struct RegionStateDTO: Decodable, Sendable {
        let alertnow: Bool
        let changed: String
    }

    let source: String
    let cachedat: String
    let states: [String: RegionStateDTO]
}

