import Foundation
@testable import RegionalCheck
import Testing

/// STATUS-reason AC-4 and AC-5: where the reason is spoken, and when the list row replaces the map.
struct StatusHeroReasonTests {
    @Test("STATUS-reason AC-5 VoiceOver reads the status, the region, the reason, then the update time")
    func voiceOverOrder() {
        let spoken = StatusHeroCard.accessibilityText(
            title: "Stay Alert", region: "Kyiv", reason: "Alert nearby: Kyiv Oblast", meta: "Updated 12:38")
        #expect(spoken == "Stay Alert, Kyiv, Alert nearby: Kyiv Oblast, Updated 12:38")
    }

    @Test("STATUS-reason AC-5 without a reason VoiceOver leaves no empty slot")
    func voiceOverWithoutReason() {
        let spoken = StatusHeroCard.accessibilityText(
            title: "No Alert", region: "Lviv", reason: nil, meta: "Updated 12:38")
        #expect(spoken == "No Alert, Lviv, Updated 12:38")
        let empty = StatusHeroCard.accessibilityText(
            title: "No Alert", region: "Lviv", reason: "", meta: "Updated 12:38")
        #expect(empty == spoken)
    }

}

/// STATUS-reason AC-4 through a real `MapViewModel`: the row follows the map's own load outcome,
/// the same model `StatusView` reads, so keying it on loading instead of failure turns this red.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct StatusRegionListRowTests {
    private func makeMap(_ result: (Data, URLResponse)) throws -> (MapViewModel, SequencingHTTPClient) {
        let client = try SequencingHTTPClient(results: [.success(result)])
        let map = MapViewModel(
            statusSource: MapStatusStub(snapshot: TestSnapshots.quiet), httpClient: client, sleep: { _ in })
        return (map, client)
    }

    private func settle(_ map: MapViewModel) async {
        await Task.yield()
        let settled = await eventually { !map.isLoading }
        #expect(settled, "the map load did not settle")
    }

    @Test("STATUS-reason AC-4 a failed map is replaced by the region list row")
    func failedMapShowsTheRow() async throws {
        let (map, _) = try makeMap((Data(), MapResponses.response(statusCode: 500)))
        map.appear()
        await settle(map)
        #expect(map.loadFailed)
        #expect(StatusRegionListRow.isShown(map: map))
    }

    @Test("STATUS-reason AC-4 a loading or loaded map opens the list itself, so no row")
    func loadingAndLoadedMapsShowNoRow() async throws {
        let (map, _) = try makeMap((Data([0x01]), MapResponses.response(statusCode: 200)))
        #expect(!StatusRegionListRow.isShown(map: map), "before its first load")
        map.appear()
        #expect(!StatusRegionListRow.isShown(map: map), "while loading")
        await settle(map)
        #expect(map.imageData == Data([0x01]))
        #expect(!StatusRegionListRow.isShown(map: map), "loaded")
    }

    @Test("STATUS-reason AC-4 a host without a map shows the row")
    func noMapShowsTheRow() {
        #expect(StatusRegionListRow.isShown(map: nil))
    }
}
