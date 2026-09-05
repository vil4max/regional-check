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

    @Test
    @MainActor
    func carPlayPrimaryStatusRemainsDeterministicWhileDetailsAreLoading() {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let state = StatusState.alarm(lastCheckedAt: checkedAt)

        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: "Kyiv City",
            detailsState: .loading
        )

        #expect(content.title == state.title)
        #expect(content.regionTitle == "Kyiv City")
        #expect(content.regionDetail == state.detailText)
        #expect(content.detailRows == [state.explanation])
        #expect(content.usesStatusDetails == false)
    }

    @Test
    @MainActor
    func carPlayAIEnhancementChangesOnlySupplementaryRows() {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let state = StatusState.quiet(lastCheckedAt: checkedAt)

        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: "Kyiv City",
            detailsState: .result(["Generated country context", "Generated nearby context"])
        )

        #expect(content.title == state.title)
        #expect(content.regionTitle == "Kyiv City")
        #expect(content.regionDetail == state.detailText)
        #expect(content.detailRows == ["Generated country context", "Generated nearby context"])
        #expect(content.usesStatusDetails)
    }

    @Test
    @MainActor
    func carPlayLimitsGeneratedRowsToThree() {
        let state = StatusState.quiet(lastCheckedAt: Date(timeIntervalSince1970: 1_700_000_000))

        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: "Kyiv City",
            detailsState: .result(["1", "2", "3", "4"])
        )

        #expect(content.detailRows == ["1", "2", "3"])
        #expect(content.usesStatusDetails)
    }
}
