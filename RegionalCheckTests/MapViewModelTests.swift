// swiftlint:disable force_unwrapping
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct MapViewModelTests {
    @Test
    func appearLoadsImageOnceAndStampsFetchTime() async {
        let now = Date(timeIntervalSince1970: 42)
        let client = MockHTTPClient(mapData: Data([0x89, 0x50]), statusCode: 200)
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
    func repeatedAppearAndRefreshWhileLoadingIssueOneRequest() async {
        let client = GatedHTTPClient()
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        #expect(viewModel.isLoading == true)
        await client.waitUntilRequested()
        #expect(await client.requestCount == 1)

        viewModel.appear()
        viewModel.refresh()
        #expect(await client.requestCount == 1)

        await client.finish(statusCode: 200)
        await drain(viewModel)

        #expect(await client.requestCount == 1)
        #expect(viewModel.imageData != nil)
    }

    @Test
    func refreshAfterSuccessReloadsAndRestamps() async {
        let first = Date(timeIntervalSince1970: 10)
        let second = Date(timeIntervalSince1970: 20)
        var clock = first
        let client = MockHTTPClient(mapData: Data([0x01]), statusCode: 200)
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
    func failureWithoutImageSurfacesError() async {
        let client = MockHTTPClient(mapData: Data(), statusCode: 500)
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await drain(viewModel)

        #expect(viewModel.imageData == nil)
        #expect(viewModel.loadedAt == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.loadFailed == true)
    }

    @Test
    func retryAfterFailureIssuesNewRequestAndCanRecover() async {
        let client = SequencingHTTPClient(results: [
            .success((Data(), MapResponses.serverError)),
            .success((Data([0x42]), MapResponses.ok))
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
    func failedReloadKeepsPreviousImage() async {
        let client = SequencingHTTPClient(results: [
            .success((Data([0x09]), MapResponses.ok)),
            .success((Data(), MapResponses.serverError))
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
    func disappearCancelsInflightLoadWithoutApplyingState() async {
        let client = GatedHTTPClient()
        let viewModel = makeViewModel(client: client)

        viewModel.appear()
        await client.waitUntilRequested()
        viewModel.disappear()
        await client.finish(statusCode: 200)
        await drain(viewModel)

        #expect(viewModel.imageData == nil)
        #expect(viewModel.loadedAt == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test
    func variantChangeReloadsOnlyWhenImageLoaded() async {
        let client = RecordingHTTPClient(result: .success((Data([0x07]), MapResponses.ok)))
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
    func appearWaitsForStatusToSettleThenDelaysBeforeRequesting() async {
        let statusSource = MapStatusStub(snapshot: TestSnapshots.quiet)
        statusSource.blockUntilResolved()
        let client = MockHTTPClient(mapData: Data([0x0A]), statusCode: 200)
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
        #expect(sleptDurations == [.seconds(1.5)])
    }

    @Test
    func refreshDoesNotWaitForStatusOrDelay() async {
        let statusSource = MapStatusStub(snapshot: TestSnapshots.quiet)
        let client = MockHTTPClient(mapData: Data([0x03]), statusCode: 200)
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
        let client = MockHTTPClient(mapData: Data([0x03]), statusCode: 200)
        let viewModel = MapViewModel(statusSource: source, httpClient: client, now: Date.init, sleep: { _ in })

        viewModel.appear()
        await drain(viewModel)
        let quietLabel = try TestLocale.english { viewModel.accessibilityLabel }

        source.snapshot = TestSnapshots.alarms([.lviv])
        let alarmLabel = try TestLocale.english { viewModel.accessibilityLabel }

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

    private func drain(_ viewModel: MapViewModel) async {
        for _ in 0 ..< 50 {
            if !viewModel.isLoading {
                await Task.yield()
                if !viewModel.isLoading {
                    return
                }
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
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
    static let ok = HTTPURLResponse(
        url: MapImageSource.url(for: .day),
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!
    static let serverError = HTTPURLResponse(
        url: MapImageSource.url(for: .day),
        statusCode: 500,
        httpVersion: nil,
        headerFields: nil
    )!
}

private extension MockHTTPClient {
    convenience init(mapData: Data, statusCode: Int) {
        let response = HTTPURLResponse(
            url: MapImageSource.url(for: .day),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        self.init(data: mapData, response: response)
    }
}

/// HTTPClient double that suspends the in-flight request until the test
/// calls `finish`, with cooperative cancellation like a real transport.
/// Actor isolation replaces the manual locking a plain class would need;
/// mirrors `GatedModelClient`'s shape for the map-image endpoint.
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

    func finish(statusCode: Int) {
        let response = HTTPURLResponse(
            url: MapImageSource.url(for: .day),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
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

private final class RecordingHTTPClient: HTTPClient, @unchecked Sendable {
    let result: Result<(Data, URLResponse), any Error>
    private(set) var requests: [URLRequest] = []
    var requestCount: Int {
        requests.count
    }

    init(result: Result<(Data, URLResponse), any Error>) {
        self.result = result
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return try result.get()
    }
}
