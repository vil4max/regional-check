import Foundation
@testable import RegionalCheck
import Testing

/// The registration client and the app's behaviour while the server answers 404 or is down
/// (REQ-PUSH-001): nothing is shown, and the next foreground tries again.
/// Serialized: the stub protocol is process-wide, so two tests installing it at once would
/// record each other's requests.
@Suite(.serialized)
@MainActor
struct PushClientTests {
    @Test("REQ-PUSH-006 the client sends PUT and DELETE to /v1/push/registration, and a 404 is an error")
    func clientSpeaksTheContractAndRejectsA404() async throws {
        let recorder = PushStubURLProtocol.install { request in
            (request.url?.path == "/v1/push/registration" && request.httpMethod != "DELETE") ? 204 : 404
        }
        defer { PushStubURLProtocol.uninstall() }
        let client = URLSessionPushRegistrationClient(
            baseURL: try #require(URL(string: "https://push.example.test")),
            session: PushStubURLProtocol.session())

        try await client.put(PushRegistration(token: "ab", region: "kharkiv", env: "production", lang: "uk"))
        let put = try #require(recorder.requests.first)
        #expect(put.method == "PUT")
        #expect(put.path == "/v1/push/registration")
        #expect(Set(put.bodyKeys) == ["token", "region", "env", "lang"])

        // The server before its deploy: the DELETE route answers 404 in this stub.
        await #expect(throws: URLError.self) { try await client.delete(token: "ab") }
        #expect(recorder.requests.last?.method == "DELETE")
        #expect(recorder.requests.last?.bodyKeys == ["token"])
    }

    @Test(
        "ALERT-push AC-2 the Live Activity client sends PUT and DELETE to /v1/push/live-activity, and a 404 is an error"
    )
    func liveActivityClientSpeaksTheContract() async throws {
        let recorder = PushStubURLProtocol.install { request in
            (request.url?.path == "/v1/push/live-activity" && request.httpMethod != "DELETE") ? 204 : 404
        }
        defer { PushStubURLProtocol.uninstall() }
        let client = URLSessionLiveActivityPushClient(
            baseURL: try #require(URL(string: "https://push.example.test")),
            session: PushStubURLProtocol.session())

        try await client.put(
            LiveActivityPushRecord(
                startToken: "01", region: "kharkiv", env: "production", lang: "uk", activityToken: "ab"))
        let put = try #require(recorder.requests.first)
        #expect(put.method == "PUT")
        #expect(put.path == "/v1/push/live-activity")
        #expect(Set(put.bodyKeys) == ["startToken", "region", "env", "lang", "activityToken"])

        await #expect(throws: URLError.self) { try await client.delete(startToken: "01") }
        #expect(recorder.requests.last?.method == "DELETE")
        #expect(recorder.requests.last?.bodyKeys == ["startToken"])
    }

    /// BUG-LA-push-start H2: a refused record must say why in the device log, so the error keeps
    /// the server's status instead of a bare `badServerResponse`.
    @Test(
        "REQ-PUSH-008 a refused Live Activity registration reports its HTTP status",
        arguments: [400, 503]
    )
    func refusedLiveActivityRegistrationCarriesItsStatus(status: Int) async throws {
        _ = PushStubURLProtocol.install { _ in status }
        defer { PushStubURLProtocol.uninstall() }
        let client = URLSessionLiveActivityPushClient(
            baseURL: try #require(URL(string: "https://push.example.test")),
            session: PushStubURLProtocol.session())
        let record = LiveActivityPushRecord(
            startToken: "01", region: "kharkiv", env: "production", lang: "uk", activityToken: nil)

        let putError = await #expect(throws: URLError.self) { try await client.put(record) }
        #expect(putError?.httpStatus == status)
        let deleteError = await #expect(throws: URLError.self) { try await client.delete(startToken: "01") }
        #expect(deleteError?.httpStatus == status)
    }

    @Test("REQ-PUSH-008 an accepted Live Activity registration is no error")
    func acceptedLiveActivityRegistrationSucceeds() async throws {
        _ = PushStubURLProtocol.install { _ in 204 }
        defer { PushStubURLProtocol.uninstall() }
        let client = URLSessionLiveActivityPushClient(
            baseURL: try #require(URL(string: "https://push.example.test")),
            session: PushStubURLProtocol.session())

        try await client.put(
            LiveActivityPushRecord(
                startToken: "01", region: "kharkiv", env: "production", lang: "uk", activityToken: nil))
        try await client.delete(startToken: "01")
    }

    @Test("REQ-PUSH-001 a server that answers 404 is met in silence and retried on the next foreground")
    func unreachableServerIsSilentAndRetried() async {
        let rig = Rig(region: .kharkiv)
        rig.client.fails = true

        await rig.controller.setEnabled(true)
        await rig.controller.didRegister(deviceToken: Data([0x0C]))

        // Nothing for the driver to see: the switch still reads on and no registration is recorded.
        #expect(rig.controller.isSwitchOn)
        #expect(rig.client.puts.isEmpty)

        rig.client.fails = false
        await rig.controller.sceneDidBecomeActive()
        #expect(rig.client.puts.map(\.token) == ["0c"])
    }
}

/// Answers every request from a closure and records it; installed per test.
class PushStubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Seen {
        let method: String
        let path: String
        let bodyKeys: [String]
    }

    final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var seen: [Seen] = []
        var requests: [Seen] { lock.withLock { seen } }
        func add(_ item: Seen) { lock.withLock { seen.append(item) } }
    }

    nonisolated(unsafe) private static var statusFor: (@Sendable (URLRequest) -> Int)?
    nonisolated(unsafe) private static var recorder: Recorder?

    static func install(_ status: @escaping @Sendable (URLRequest) -> Int) -> Recorder {
        let recorder = Recorder()
        statusFor = status
        self.recorder = recorder
        return recorder
    }

    static func uninstall() {
        statusFor = nil
        recorder = nil
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PushStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
        } else {
            body = request.httpBody ?? Data()
        }
        let keys = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?.keys.map { $0 } ?? []
        Self.recorder?.add(
            Seen(method: request.httpMethod ?? "", path: request.url?.path ?? "", bodyKeys: keys.sorted()))
        let status = Self.statusFor?(request) ?? 500
        if let url = request.url,
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil, headerFields: nil)
        {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
