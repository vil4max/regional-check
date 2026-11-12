import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Synchronization
import Testing

/// MAP-sync: the inline map follows the status it sits under. A loaded map reloads when an
/// accepted snapshot changes the set of regions in alarm, never shows an image of another set,
/// and every map request bypasses the local HTTP cache.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct MapViewModelSyncTests {
    private let kyiv = TestSnapshots.alarms([.kyivCity])
    private let kyivAndOblast = TestSnapshots.alarms([.kyivCity, .kyivOblast])

    @Test("REQ-PROVIDER-002 MAP-sync AC-1 a status that changes the alarm set reloads the loaded map once")
    func alarmSetChangeReloadsOnce() async throws {
        let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02, 0x03])

        rig.model.appear()
        await rig.drain()
        #expect(rig.client.requestCount == 1)

        rig.status.snapshot = kyivAndOblast
        rig.model.statusDidChange()
        await rig.drain()
        #expect(rig.client.requestCount == 2)
        #expect(rig.model.visibleImageData == Data([0x02]))
        // The new trigger keeps the polite order: settle, then the delay, then the request.
        #expect(rig.events.suffix(3) == ["settle", "delay", "request"])

        // A new snapshot with the same set (only the check time moves) adds no request.
        rig.status.snapshot = TestSnapshots.alarms([.kyivOblast, .kyivCity])
        rig.model.statusDidChange()
        await rig.drain()
        #expect(rig.client.requestCount == 2)
        #expect(rig.model.visibleImageData == Data([0x02]))
    }

    @Test("REQ-PROVIDER-002 MAP-sync AC-1 a map loaded before any snapshot reloads once the first one arrives")
    func firstSnapshotAfterAnImageReloads() async throws {
        let rig = try SyncRig(snapshot: nil, images: [0x01, 0x02])

        rig.model.appear()
        await rig.drain()
        #expect(rig.model.visibleImageData == Data([0x01]))

        rig.status.snapshot = kyiv
        rig.model.statusDidChange()
        await rig.drain()
        #expect(rig.client.requestCount == 2)
        #expect(rig.model.visibleImageData == Data([0x02]))
    }

    @Test("REQ-PROVIDER-002 MAP-sync AC-1 an alarm-set change sends nothing outside a live loaded session")
    func alarmSetChangeOutsideALoadedSessionIsSilent() async throws {
        // Never loaded: a CarPlay-only launch polls without the phone card ever appearing.
        let neverLoaded = try SyncRig(snapshot: kyiv, images: [0x01])
        neverLoaded.status.snapshot = kyivAndOblast
        neverLoaded.model.statusDidChange()
        await neverLoaded.drain()
        #expect(neverLoaded.client.requestCount == 0)

        // Session ended: the phone went to the background while CarPlay keeps polling.
        let backgrounded = try SyncRig(snapshot: kyiv, images: [0x01, 0x02])
        backgrounded.model.appear()
        await backgrounded.drain()
        backgrounded.model.endForegroundSession()
        backgrounded.status.snapshot = kyivAndOblast
        backgrounded.model.statusDidChange()
        await backgrounded.drain()
        #expect(backgrounded.client.requestCount == 1)

        // Failed: only a pull or a new session retries a hidden map.
        let failed = try SyncRig(snapshot: kyiv, results: [.failure(statusCode: 500)])
        failed.model.appear()
        await failed.drain()
        #expect(failed.model.loadFailed)
        failed.status.snapshot = kyivAndOblast
        failed.model.statusDidChange()
        await failed.drain()
        #expect(failed.client.requestCount == 1)
    }

    @Test("MAP-sync AC-3 the card never shows an image of another alarm set")
    func noImageOfAnotherSet() async throws {
        let rig = try SyncRig(snapshot: kyiv, results: [.image(0x01), .failure(statusCode: 500)])
        rig.model.appear()
        await rig.drain()
        #expect(rig.model.visibleImageData == Data([0x01]))

        // The status moves before any observer or task has run: the old picture is already gone.
        rig.status.snapshot = kyivAndOblast
        #expect(rig.model.visibleImageData == nil)

        rig.model.statusDidChange()
        #expect(rig.model.visibleImageData == nil)
        await rig.drain()
        #expect(rig.model.loadFailed)
        #expect(rig.model.visibleImageData == nil)
    }

    @Test("MAP-sync AC-4 the map request bypasses the local cache")
    func mapRequestBypassesTheCache() async throws {
        let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02])
        rig.model.appear()
        await rig.drain()
        rig.status.snapshot = kyivAndOblast
        rig.model.statusDidChange()
        await rig.drain()

        #expect(rig.client.cachePolicies == [.reloadIgnoringLocalCacheData, .reloadIgnoringLocalCacheData])
    }

    @Test("MAP-sync AC-5 a status change while the delay runs adds no second request")
    func changeDuringTheDelayKeepsOneRequest() async throws {
        let rig = try SyncRig(snapshot: kyiv, images: [0x01, 0x02])
        rig.status.blockUntilResolved()

        rig.model.appear()
        rig.status.snapshot = kyivAndOblast
        rig.model.statusDidChange()
        rig.status.resolveSettled()
        await rig.drain()

        #expect(rig.client.requestCount == 1)
        #expect(rig.model.visibleImageData == Data([0x01]))
    }

    @Test("MAP-sync AC-5 a status change after the request left supersedes it")
    func changeAfterTheRequestSupersedesIt() async throws {
        let client = SyncGatedHTTPClient()
        let status = SyncStatusStub(snapshot: kyiv)
        let model = MapViewModel(statusSource: status, httpClient: client, sleep: { _ in })

        model.appear()
        try #require(await eventually { client.requestCount == 1 })
        status.snapshot = kyivAndOblast
        model.statusDidChange()
        try #require(await eventually { client.requestCount == 2 })
        try client.finish(request: 1, byte: 0x01)
        try client.finish(request: 2, byte: 0x02)
        let settled = await eventually { !model.isLoading }
        #expect(settled)

        #expect(model.imageData == Data([0x02]))
        #expect(model.visibleImageData == Data([0x02]))
    }
}

// MARK: - Test doubles

/// One map view model with a status stub and an HTTP client that share an event log, so a test can
/// check the order settle → delay → request.
@MainActor
private final class SyncRig {
    enum Reply {
        case image(UInt8)
        case failure(statusCode: Int)
    }

    let status: SyncStatusStub
    let client: SyncRecordingHTTPClient
    let model: MapViewModel
    private let log: EventLog

    var events: [String] { log.events }

    convenience init(snapshot: AlertsSnapshot?, images: [UInt8]) throws {
        try self.init(snapshot: snapshot, results: images.map { .image($0) })
    }

    init(snapshot: AlertsSnapshot?, results: [Reply]) throws {
        let log = EventLog()
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

private final class EventLog: Sendable {
    private let storage = Mutex<[String]>([])
    var events: [String] { storage.withLock { $0 } }

    func append(_ event: String) {
        storage.withLock { $0.append(event) }
    }
}

@MainActor
private final class SyncStatusStub: RegionStatusSource {
    var snapshot: AlertsSnapshot?
    private let log: EventLog?
    private var isSettled = true
    private var settleContinuation: CheckedContinuation<Void, Never>?

    init(snapshot: AlertsSnapshot?, log: EventLog? = nil) {
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

private final class SyncRecordingHTTPClient: HTTPClient {
    private struct State {
        var replies: [(Data, URLResponse)]
        var policies: [URLRequest.CachePolicy] = []
    }

    private let state: Mutex<State>
    private let log: EventLog

    var requestCount: Int { state.withLock { $0.policies.count } }
    var cachePolicies: [URLRequest.CachePolicy] { state.withLock { $0.policies } }

    init(replies: [(Data, URLResponse)], log: EventLog) {
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
private final class SyncGatedHTTPClient: HTTPClient {
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
