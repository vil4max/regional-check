import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// The inline map is fetched once per phone foreground session, like the status above it — not
/// once per process. A process can sit in the background for hours, and its first image would
/// otherwise stay under every later session's fresh status.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MapViewModelSessionTests {
    @Test
    func newForegroundSessionDropsThePreviousImageAndLoadsItsOwn() async throws {
        let evening = Date(timeIntervalSince1970: 1_000_000)
        let morning = evening.addingTimeInterval(11 * 3600)
        var clock = evening
        let client = try SequencingHTTPClient(results: [
            .success((Data([0x01]), MapResponses.response(statusCode: 200))),
            .success((Data([0x02]), MapResponses.response(statusCode: 200))),
        ])
        let viewModel = makeViewModel(client: client, now: { clock })

        viewModel.appear()
        await drain(viewModel)
        viewModel.endForegroundSession()
        clock = morning
        viewModel.appear()

        // Until the new image lands the card shows its placeholder, never last night's raster
        // and its "11 h ago" under this morning's status.
        #expect(viewModel.imageData == nil)
        #expect(viewModel.fullscreenCaption == nil)
        await drain(viewModel)
        #expect(client.requestCount == 2)
        #expect(viewModel.imageData == Data([0x02]))
        #expect(viewModel.loadedAt == morning)
    }

    @Test
    func newForegroundSessionRetriesAMapThatFailedInThePreviousOne() async throws {
        let client = try SequencingHTTPClient(results: [
            .success((Data(), MapResponses.response(statusCode: 500))),
            .success((Data([0x03]), MapResponses.response(statusCode: 200))),
        ])
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await drain(viewModel)
        #expect(viewModel.loadFailed == true)
        viewModel.endForegroundSession()
        viewModel.appear()
        await drain(viewModel)

        #expect(client.requestCount == 2)
        #expect(viewModel.loadFailed == false)
        #expect(viewModel.imageData == Data([0x03]))
    }

    @Test("REQ-PROVIDER-002 a second appearance in the same foreground session issues no map request")
    func appearingAgainInTheSameSessionKeepsTheImage() async throws {
        let client = try MockHTTPClient(data: Data([0x04]), response: MapResponses.response(statusCode: 200))
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await drain(viewModel)
        viewModel.appear()
        await drain(viewModel)

        #expect(client.requestCount == 1)
        #expect(viewModel.imageData == Data([0x04]))
    }

    private func makeViewModel(
        client: any HTTPClient,
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 7) }
    ) -> MapViewModel {
        MapViewModel(
            statusSource: MapStatusStub(snapshot: TestSnapshots.quiet),
            httpClient: client,
            now: now,
            sleep: { _ in }
        )
    }

    private func drain(_ viewModel: MapViewModel, sourceLocation: SourceLocation = #_sourceLocation) async {
        await Task.yield()
        let settled = await eventually { !viewModel.isLoading }
        #expect(settled, "the map load did not settle", sourceLocation: sourceLocation)
    }
}
