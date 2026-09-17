import Foundation

struct EntitlementSnapshot: Equatable, Codable {
    let productID: String
    let expirationDate: Date?
    let isActive: Bool
    let source: String
    let verifiedAt: Date
}
