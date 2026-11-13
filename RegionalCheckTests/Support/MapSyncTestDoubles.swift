import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

/// One map view model with a status stub and an HTTP client that share an event log, so a test can
/// check the order settle → delay → request.
@MainActor
final class SyncRig {
    enum Reply {
        case image(UInt8)
        case failure(statusCode: Int)
    }

    let status: SyncStatusStub
    let client: SyncRecordingHTTPClient
    let model: MapViewModel
    private let log: MapSyncEventLog

    var events: [String] { log.events }

    convenience init(snapshot: AlertsSnapshot?, images: [UInt8]) throws {
        try self.init(snapshot: snapshot, results: images.map { .image($0) })
    }

    init(snapshot: AlertsSnapshot?, results: [Reply]) throws {
        let log = MapSyncEventLog()
        self.log = log
        status = SyncStatusStub(snapshot: snapshot, log: log)
        let replies: [(Data, URLResponse)] = try results.map { reply in
            switch reply {
            case .image(let byte):
                return (Data([byte]), try MapResponses.response(statusCode: 200))
            case .failure(let statusCode):
                return (Data(), try MapResponses.response(statusCode: statusCode))
            }
        }
        client = SyncRecordingHTTPClient(replies: replies, log: log)
        model = MapViewModel(
            statusSource: status,
            httpClient: client,
            sleep: { _ in log.append("delay") }
        )
    }

    func drain(sourceLocation: SourceLocation = #_sourceLocation) async {
        await Task.yield()
        let settled = await eventually { !self.model.isLoading }
        #expect(settled, "the map load did not settle", sourceLocation: sourceLocation)
    }
}

final class MapSyncEventLog: Sendable {
    private let storage = Mutex<[String]>([])
    var events: [String] { storage.withLock { $0 } }

    func append(_ event: String) {
        storage.withLock { $0.append(event) }
    }
}

@MainActor
final class SyncStatusStub: RegionStatusSource {
    var snapshot: AlertsSnapshot?
    private let log: MapSyncEventLog?
    private var isSettled = true
    private var settleContinuation: CheckedContinuation<Void, Never>?

    init(snapshot: AlertsSnapshot?, log: MapSyncEventLog? = nil) {
        self.snapshot = snapshot
        self.log = log
    }

    var lastSnapshot: AlertsSnapshot? { snapshot }

    func blockUntilResolved() {
        isSettled = false
    }

    func resolveSettled() {
        isSettled = true
        settleContinuation?.resume()
        settleContinuation = nil
    }

    func awaitStatusSettled() async {
        log?.append("settle")
        guard !isSettled else { return }
        await withCheckedContinuation { settleContinuation = $0 }
    }
}

final class SyncRecordingHTTPClient: HTTPClient {
    private struct State {
        var replies: [(Data, URLResponse)]
        var policies: [URLRequest.CachePolicy] = []
    }

    private let state: Mutex<State>
    private let log: MapSyncEventLog

    var requestCount: Int { state.withLock { $0.policies.count } }
    var cachePolicies: [URLRequest.CachePolicy] { state.withLock { $0.policies } }

    init(replies: [(Data, URLResponse)], log: MapSyncEventLog) {
        state = Mutex(State(replies: replies))
        self.log = log
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        log.append("request")
        let reply = state.withLock { state -> (Data, URLResponse)? in
            state.policies.append(request.cachePolicy)
            return state.replies.isEmpty ? nil : state.replies.removeFirst()
        }
        guard let reply else { throw URLError(.unknown) }
        return reply
    }
}

/// Holds each request until the test finishes it by number, so two generations can overlap.
/// A cancelled generation still waits for its reply: the test proves the late response is
/// ignored, not that the transport dropped it.
final class SyncGatedHTTPClient: HTTPClient {
    private struct State {
        var count = 0
        var pending: [Int: CheckedContinuation<(Data, URLResponse), any Error>] = [:]
    }

    private let state = Mutex(State())
    var requestCount: Int { state.withLock { $0.count } }

    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock { state in
                state.count += 1
                state.pending[state.count] = continuation
            }
        }
    }

    func finish(request number: Int, byte: UInt8) throws {
        let response = try MapResponses.response(statusCode: 200)
        let continuation = state.withLock { $0.pending.removeValue(forKey: number) }
        continuation?.resume(returning: (Data([byte]), response))
    }
}
