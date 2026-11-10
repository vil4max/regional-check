import DriveCheckKit
import Foundation
import os

/// What the server keeps for a device's Live Activity (ALERT-push AC-2, AC-9): the ActivityKit
/// push-to-start token (the record's key), the region, the APNs environment, the language of the
/// activity's text, and the update token of the running activity when there is one.
struct LiveActivityPushRecord: Codable, Equatable, Sendable {
    let startToken: String
    let region: String
    let env: String
    let lang: String
    let activityToken: String?
}

protocol LiveActivityPushSending: Sendable {
    func put(_ record: LiveActivityPushRecord) async throws
    func delete(startToken: String) async throws
}

/// Where the Live Activity controller reports ActivityKit tokens and whether activities may run.
@MainActor
protocol LiveActivityTokenSink: AnyObject {
    func startTokenDidChange(_ token: Data)
    func activityTokenDidChange(_ token: Data?)
    func liveActivitiesAllowedDidChange(_ allowed: Bool)
}

/// `PUT` and `DELETE /v1/push/live-activity` of drivecheck-api.
struct URLSessionLiveActivityPushClient: LiveActivityPushSending {
    var baseURL: URL = URL(string: "https://drivecheck.vil4max.com") ?? URL(filePath: "/")
    var session: URLSession = .shared

    func put(_ record: LiveActivityPushRecord) async throws {
        try await send(method: "PUT", body: record)
    }

    func delete(startToken: String) async throws {
        try await send(method: "DELETE", body: ["startToken": startToken])
    }

    private func send(method: String, body: some Encodable) async throws {
        var request = URLRequest(url: baseURL.appending(path: "v1/push/live-activity"))
        request.httpMethod = method
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

/// The client of every container but the live one: tests and fixtures never reach the server.
struct OfflineLiveActivityPushClient: LiveActivityPushSending {
    func put(_: LiveActivityPushRecord) async throws {}
    func delete(startToken _: String) async throws {}
}

/// Keeps the server's Live Activity record in step with this device, independent of the notice
/// switch (owner, 2026-11-10): while Live Activities are allowed, the server can start, update and
/// end Drive Check's activity, so an all-clear the app missed still ends it (AC-9).
@MainActor
final class LiveActivityPushRegistrar: LiveActivityTokenSink {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Push")
    static let refreshInterval: TimeInterval = 7 * 24 * 3600

    private enum Key {
        static let lastSent = "push.liveActivity.lastSent"
        static let lastSentAt = "push.liveActivity.lastSentAt"
        static let pendingDelete = "push.liveActivity.pendingDelete"
    }

    private let regions: any PushRegionProviding
    private let client: any LiveActivityPushSending
    private let defaults: UserDefaults
    private let locale: () -> Locale
    private let environment: PushRegistration.Environment
    private let now: () -> Date
    private var syncTail: Task<Void, Never>?
    private var isObservingRegion = false

    private(set) var isAllowed = false
    private var startToken: String?
    private var activityToken: String?

    init(
        regions: any PushRegionProviding,
        client: any LiveActivityPushSending = URLSessionLiveActivityPushClient(),
        defaults: UserDefaults = .standard,
        locale: @escaping () -> Locale = { .current },
        environment: PushRegistration.Environment = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.regions = regions
        self.client = client
        self.defaults = defaults
        self.locale = locale
        self.environment = environment
        self.now = now
    }

    func startTokenDidChange(_ token: Data) {
        startToken = PushRegistration.tokenString(from: token)
        enqueueSync()
    }

    func activityTokenDidChange(_ token: Data?) {
        activityToken = token.map(PushRegistration.tokenString(from:))
        enqueueSync()
    }

    func liveActivitiesAllowedDidChange(_ allowed: Bool) {
        guard allowed != isAllowed else { return }
        isAllowed = allowed
        enqueueSync()
    }

    /// A failed PUT or DELETE is retried on the next foreground, and the weekly refresh runs
    /// there too, as for the notice registration (REQ-PUSH-001, REQ-PUSH-003).
    func sceneDidBecomeActive() async {
        await enqueueSync().value
    }

    func sync() async {
        await enqueueSync().value
    }

    func idle() async {
        await syncTail?.value
    }

    /// Re-syncs whenever the eligible region changes; safe to call more than once.
    func startObservingRegionChanges() {
        guard !isObservingRegion else { return }
        isObservingRegion = true
        observeRegion()
    }

    private func observeRegion() {
        withObservationTracking {
            _ = regions.pushEligibleRegion
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.enqueueSync()
                self?.observeRegion()
            }
        }
    }

    @discardableResult
    private func enqueueSync() -> Task<Void, Never> {
        let previous = syncTail
        let task = Task { @MainActor in
            await previous?.value
            await performSync()
        }
        syncTail = task
        return task
    }

    private var lastSent: LiveActivityPushRecord? {
        get {
            defaults.data(forKey: Key.lastSent)
                .flatMap { try? JSONDecoder().decode(LiveActivityPushRecord.self, from: $0) }
        }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.lastSent) }
    }

    private func performSync() async {
        await flushPendingDelete()
        guard isAllowed else {
            await forget()
            return
        }
        guard let startToken, let region = regions.pushEligibleRegion else { return }
        let record = LiveActivityPushRecord(
            startToken: startToken,
            region: region.rawValue,
            env: environment.rawValue,
            lang: PushRegistration.language(for: locale()),
            activityToken: activityToken
        )
        let sentAt = defaults.object(forKey: Key.lastSentAt) as? Date ?? .distantPast
        guard record != lastSent || now().timeIntervalSince(sentAt) >= Self.refreshInterval else { return }
        if let previous = lastSent, previous.startToken != startToken {
            defaults.set(previous.startToken, forKey: Key.pendingDelete)
        }
        do {
            try await client.put(record)
            lastSent = record
            defaults.set(now(), forKey: Key.lastSentAt)
            // The old start token's record goes as soon as the new one is in place.
            await flushPendingDelete()
        } catch {
            Self.log.error("live activity registration failed, retrying on the next change")
        }
    }

    private func flushPendingDelete() async {
        guard let stale = defaults.string(forKey: Key.pendingDelete) else { return }
        if (try? await client.delete(startToken: stale)) != nil {
            defaults.removeObject(forKey: Key.pendingDelete)
        }
    }

    private func forget() async {
        guard let sent = lastSent else { return }
        lastSent = nil
        do {
            try await client.delete(startToken: sent.startToken)
        } catch {
            defaults.set(sent.startToken, forKey: Key.pendingDelete)
        }
    }
}
