import Foundation
@testable import RegionalCheck
import Testing

struct CarPlayConnectionTests {
    @Test
    func connect_isIdempotent() {
        var gate = CarPlayConnectionGate()
        let first = gate.connect()
        #expect(first)
        #expect(gate.isConnected)
        let second = gate.connect()
        #expect(second == false)
        #expect(gate.isConnected)
    }

    @Test
    func disconnect_isIdempotent() {
        var gate = CarPlayConnectionGate()
        let firstDisconnect = gate.disconnect()
        #expect(firstDisconnect == false)
        let connected = gate.connect()
        #expect(connected)
        let disconnected = gate.disconnect()
        #expect(disconnected)
        #expect(gate.isConnected == false)
        let secondDisconnect = gate.disconnect()
        #expect(secondDisconnect == false)
    }

    @Test
    @MainActor
    func appDelegate_bootstrapsCarPlayDependenciesBeforeSceneConfiguration() {
        CarPlaySceneDelegate.dependenciesProvider = nil

        _ = AppDelegate()

        #expect(CarPlaySceneDelegate.dependenciesProvider != nil)
    }

    @Test
    @MainActor
    func periodicRefresh_survivesDuplicateCarPlayConnectDisconnect() {
        let controller = StatusController(
            region: .kyivCity,
            provider: MockStatusProvider(snapshot: TestFixtures.quietSnapshot())
        )
        controller.beginPeriodicRefresh()
        controller.beginPeriodicRefresh()
        controller.endPeriodicRefresh()
        controller.endPeriodicRefresh()
        #expect(Bool(true))
    }
}
