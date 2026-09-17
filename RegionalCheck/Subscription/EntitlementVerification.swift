import Foundation

enum EntitlementVerification: Equatable, Sendable {
    case active(EntitlementSnapshot)
    case none
    case unverified
}

enum RestoreOutcome: Equatable, Sendable {
    case restored
    case empty
    case failed
}
