import Foundation

struct CarPlayConnectionGate: Sendable {
    private(set) var isConnected = false

    mutating func connect() -> Bool {
        guard !isConnected else { return false }
        isConnected = true
        return true
    }

    mutating func disconnect() -> Bool {
        guard isConnected else { return false }
        isConnected = false
        return true
    }
}
