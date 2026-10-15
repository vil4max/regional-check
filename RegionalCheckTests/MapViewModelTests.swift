import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MapViewModelTests {
    @Test
    func appearLoadsImageOnceAndStampsFetchTime() async throws {
        let now = Date(timeIntervalSince1970: 42)
        let client = try MockHTTPClient(mapData: Data([0x89, 0x50]), statusCode: 200)
        let viewModel = makeViewModel(client: client, now: { now })

        viewModel.appear()
        await drain(viewModel)

        #expect(viewModel.imageData == Data([0x89, 0x50]))
        #expect(viewModel.loadedAt == now)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.loadFailed == false)
        #expect(client.requestCount == 1)
    }

    @Test
    func repeatedAppearAndRefreshWhileLoadingIssueOneRequest() async throws {
        let client = GatedHTTPClient()
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        #expect(viewModel.isLoading == true)
        await client.waitUntilRequested()
        #expect(await client.requestCount == 1)

        viewModel.appear()
        viewModel.refresh()
        #expect(await client.requestCount == 1)

        try await client.finish(statusCode: 200)
        await drain(viewModel)

        #expect(await client.requestCount == 1)
        #expect(viewModel.imageData != nil)
    }

    @Test
    func refreshAfterSuccessReloadsAndRestamps() async throws {
        let first = Date(timeIntervalSince1970: 10)
        let second = Date(timeIntervalSince1970: 20)
        var clock = first
        let client = try MockHTTPClient(mapData: Data([0x01]), statusCode: 200)
        let viewModel = makeViewModel(client: client, now: { clock })

        viewModel.appear()
        await drain(viewModel)
        clock = second
        viewModel.refresh()
        await drain(viewModel)

        #expect(client.requestCount == 2)
        #expect(viewModel.loadedAt == second)
        #expect(viewModel.loadFailed == false)
    }

    @Test
    func failureWithoutImageSurfacesError() async throws {
        let client = try MockHTTPClient(mapData: Data(), statusCode: 500)
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await drain(viewModel)

        #expect(viewModel.imageData == nil)
        #expect(viewModel.loadedAt == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.loadFailed == true)
    }

    @Test
    func retryAfterFailureIssuesNewRequestAndCanRecover() async throws {
        let client = try SequencingHTTPClient(results: [
            .success((Data(), MapResponses.response(statusCode: 500))),
            .success((Data([0x42]), MapResponses.response(statusCode: 200))),
        ])
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await drain(viewModel)
        #expect(viewModel.loadFailed == true)
        #expect(viewModel.imageData == nil)
        #expect(client.requestCount == 1)

        viewModel.refresh()
        await drain(viewModel)
        #expect(viewModel.loadFailed == false)
        #expect(viewModel.imageData == Data([0x42]))
        #expect(client.requestCount == 2)
    }

    @Test
    func failedReloadKeepsPreviousImage() async throws {
        let client = try SequencingHTTPClient(results: [
            .success((Data([0x09]), MapResponses.response(statusCode: 200))),
            .success((Data(), MapResponses.response(statusCode: 500))),
        ])
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await drain(viewModel)
        viewModel.refresh()
        await drain(viewModel)

        #expect(viewModel.imageData == Data([0x09]))
        #expect(viewModel.loadFailed == true)
        #expect(client.requestCount == 2)
    }

    @Test
    func disappearCancelsInflightLoadWithoutApplyingState() async throws {
        let client = GatedHTTPClient()
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await client.waitUntilRequested()
        viewModel.disappear()
        try await client.finish(statusCode: 200)
        await drain(viewModel)

        #expect(viewModel.imageData == nil)
        #expect(viewModel.loadedAt == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func variantChangeReloadsOnlyWhenImageLoaded() async throws {
        let client = try RecordingHTTPClient(result: .success((Data([0x07]), MapResponses.response(statusCode: 200))))
        let viewModel = makeViewModel(client: client)

        viewModel.setVariant(.night)
        #expect(client.requestCount == 0)

        viewModel.appear()
        await drain(viewModel)
        #expect(client.requestCount == 1)
        #expect(client.requests.last?.url?.absoluteString == MapImageSource.url(for: .night).absoluteString)

        viewModel.setVariant(.day)
        await drain(viewModel)
        #expect(client.requestCount == 2)
        #expect(client.requests.last?.url?.absoluteString == MapImageSource.url(for: .day).absoluteString)

        viewModel.setVariant(.day)
        await drain(viewModel)
        #expect(client.requestCount == 2)
    }

    @Test
    func appearWaitsForStatusToSettleThenDelaysBeforeRequesting() async throws {
        let statusSource = MapStatusStub(snapshot: TestSnapshots.quiet)
        statusSource.blockUntilResolved()
        let client = try MockHTTPClient(mapData: Data([0x0A]), statusCode: 200)
        var sleptDurations: [Duration] = []
        let viewModel = MapViewModel(
            statusSource: statusSource,
            httpClient: client,
            now: { Date(timeIntervalSince1970: 7) },
            sleep: { sleptDurations.append($0) }
        )

        viewModel.appear()
        await Task.yield()
        #expect(client.requestCount == 0)

        statusSource.resolveSettled()
        await drain(viewModel)

        #expect(client.requestCount == 1)
        #expect(sleptDurations == [MapViewModel.postStatusDelay])
        #expect(MapViewModel.postStatusDelay == .seconds(3))
    }

    @Test
    func refreshDoesNotWaitForStatusOrDelay() async throws {
        let statusSource = MapStatusStub(snapshot: TestSnapshots.quiet)
        let client = try MockHTTPClient(mapData: Data([0x03]), statusCode: 200)
        var sleptDurations: [Duration] = []
        let viewModel = MapViewModel(
            statusSource: statusSource,
            httpClient: client,
            now: { Date(timeIntervalSince1970: 7) },
            sleep: { sleptDurations.append($0) }
        )

        viewModel.refresh()
        await drain(viewModel)

        #expect(client.requestCount == 1)
        #expect(sleptDurations.isEmpty)
    }

    @Test
    func snapshotChangeRegeneratesLabelWithoutReloading() async throws {
        let source = MapStatusStub(snapshot: TestSnapshots.quiet)
        let client = try MockHTTPClient(mapData: Data([0x03]), statusCode: 200)
        let viewModel = MapViewModel(statusSource: source, httpClient: client, now: Date.init, sleep: { _ in })

        viewModel.appear()
        await drain(viewModel)
        let quietLabel = viewModel.accessibilityLabel

        source.snapshot = TestSnapshots.alarms([.lviv])
        let alarmLabel = viewModel.accessibilityLabel

        #expect(quietLabel != alarmLabel)
        #expect(alarmLabel.contains(AlertRegion.lviv.title))
        #expect(client.requestCount == 1)
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

extension MapViewModelTests {
    @Test
    func reappearingAfterFailureDoesNotRetryAutomatically() async throws {
        let client = try MockHTTPClient(mapData: Data(), statusCode: 500)
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await drain(viewModel)
        viewModel.disappear()
        viewModel.appear()
        await drain(viewModel)

        #expect(client.requestCount == 1)
        #expect(viewModel.loadFailed == true)
    }
}

@MainActor
private final class MapStatusStub: RegionStatusSource {
    var snapshot: AlertsSnapshot?

    private var isSettled = true
    private var settleContinuation: CheckedContinuation<Void, Never>?

    init(snapshot: AlertsSnapshot?) {
        self.snapshot = snapshot
    }

    var lastSnapshot: AlertsSnapshot? {
        snapshot
    }

    /// Makes `awaitStatusSettled()` suspend until `resolveSettled()` is called.
    func blockUntilResolved() {
        isSettled = false
    }

    func resolveSettled() {
        isSettled = true
        settleContinuation?.resume()
        settleContinuation = nil
    }

    func awaitStatusSettled() async {
        guard !isSettled else { return }
        await withCheckedContinuation { continuation in
            settleContinuation = continuation
        }
    }
}

private enum MapResponses {
    static func response(statusCode: Int) throws -> HTTPURLResponse {
        try #require(
            HTTPURLResponse(
                url: MapImageSource.url(for: .day),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            ))
    }
}

private extension MockHTTPClient {
    convenience init(mapData: Data, statusCode: Int) throws {
        try self.init(data: mapData, response: MapResponses.response(statusCode: statusCode))
    }
}

/// HTTPClient double that suspends the in-flight request until the test
/// calls `finish`, with cooperative cancellation like a real transport.
/// Actor isolation replaces the manual locking a plain class would need.
private actor GatedHTTPClient: HTTPClient {
    private var continuation: CheckedContinuation<(Data, URLResponse), any Error>?
    private var finishedResult: Result<(Data, URLResponse), any Error>?
    private var requestContinuation: CheckedContinuation<Void, Never>?
    private(set) var requestCount = 0

    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        requestContinuation?.resume()
        requestContinuation = nil

        if let finishedResult {
            return try finishedResult.get()
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation = $0 }
        } onCancel: {
            Task { await self.cancelPending() }
        }
    }

    func waitUntilRequested() async {
        guard requestCount == 0 else { return }
        await withCheckedContinuation { requestContinuation = $0 }
    }

    func finish(statusCode: Int) throws {
        let response = try MapResponses.response(statusCode: statusCode)
        let result: Result<(Data, URLResponse), any Error> = .success((Data([0xAA]), response))
        finishedResult = result
        continuation?.resume(with: result)
        continuation = nil
    }

    private func cancelPending() {
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

private final class RecordingHTTPClient: HTTPClient {
    let result: Result<(Data, URLResponse), any Error>
    private let recorded = Mutex<[URLRequest]>([])
    var requests: [URLRequest] { recorded.withLock { $0 } }
    var requestCount: Int {
        requests.count
    }

    init(result: Result<(Data, URLResponse), any Error>) {
        self.result = result
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        recorded.withLock { $0.append(request) }
        return try result.get()
    }
}
