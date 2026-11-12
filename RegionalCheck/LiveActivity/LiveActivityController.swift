import ActivityKit
import DriveCheckKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class LiveActivityController: LiveActivityControlling {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "LiveActivity")

    private let preference: any LiveActivityPreferenceReading
    private let liveActivityPermission: any LiveActivityPermissionSource
    private let host: any LiveActivityHosting
    private let now: () -> Date
    private let pipeline = LiveActivitySerialPipeline()
    private(set) var clients: Set<LiveActivitySessionClient> = []
    private var activity: (any LiveActivityHandle)?
    /// An activity ended green on an all-clear, still on screen for its 5 minutes (AC-9). A new
    /// activity removes it first, so two are never shown (AC-7).
    private var fading: (any LiveActivityHandle)?
    private var sentContent: SentContent?
    private var latestPhase: DriveCheckActivityPhase = .idle
    private var latestRegionTitle = ""
    private var latestCheckedAt: Date?
    private var latestSourceLabel = ""
    private var latestIsStale = false
    private var entitlementObservationTask: Task<Void, Never>?
    private var preferenceObservationTask: Task<Void, Never>?
    private var permissionObservationTask: Task<Void, Never>?
    private var startTokenTask: Task<Void, Never>?
    private var newActivityTask: Task<Void, Never>?
    private var activityTokenTask: Task<Void, Never>?
    private var latestStartToken: Data?
    private var latestActivityToken: Data?

    /// Where ActivityKit tokens go (ALERT-push AC-2, AC-9). Set by the composition root; tokens
    /// that arrived earlier are replayed.
    weak var tokenSink: (any LiveActivityTokenSink)? {
        didSet {
            tokenSink?.liveActivitiesAllowedDidChange(canRunActivity)
            if let latestStartToken {
                tokenSink?.startTokenDidChange(latestStartToken)
            }
            if let latestActivityToken {
                tokenSink?.activityTokenDidChange(latestActivityToken)
            }
        }
    }

    init(
        preference: any LiveActivityPreferenceReading,
        entitlementChanges: @escaping () -> AsyncStream<Void> = { AsyncStream { $0.finish() } },
        liveActivityPermission: any LiveActivityPermissionSource,
        host: any LiveActivityHosting,
        now: @escaping () -> Date = { Date() }
    ) {
        self.preference = preference
        self.now = now
        self.liveActivityPermission = liveActivityPermission
        self.host = host
        // Subscribe before returning so a preference write cannot race task startup.
        let preferenceChanges = preference.changes()
        preferenceObservationTask = Task { @MainActor [weak self] in
            for await _ in preferenceChanges {
                guard !Task.isCancelled else { break }
                self?.reconcileActivity()
            }
        }
        entitlementObservationTask = Task { @MainActor [weak self] in
            for await _ in entitlementChanges() {
                self?.reconcileActivity()
            }
        }
        let startTokens = host.pushToStartTokens()
        startTokenTask = Task { @MainActor [weak self] in
            for await token in startTokens {
                self?.latestStartToken = token
                self?.tokenSink?.startTokenDidChange(token)
            }
        }
        let newActivities = host.newActivities()
        newActivityTask = Task { @MainActor [weak self] in
            for await handle in newActivities {
                self?.receiveNewActivity(handle)
            }
        }
        permissionObservationTask = Task { @MainActor [weak self, liveActivityPermission] in
            for await _ in liveActivityPermission.enablementUpdates() {
                guard !Task.isCancelled else { break }
                self?.reconcileActivity()
            }
        }
    }

    isolated deinit {
        entitlementObservationTask?.cancel()
        preferenceObservationTask?.cancel()
        permissionObservationTask?.cancel()
        startTokenTask?.cancel()
        newActivityTask?.cancel()
        activityTokenTask?.cancel()
    }
}

extension LiveActivityController {
    func beginPhoneForegroundSession() {
        insert(.phoneForeground)
    }

    func endPhoneForegroundSession() {
        remove(.phoneForeground)
    }

    func beginCarPlaySession() {
        insert(.carPlay)
    }

    func endCarPlaySession() {
        remove(.carPlay)
    }

    func update(
        phase: DriveCheckActivityPhase,
        regionTitle: String,
        checkedAt: Date?,
        sourceLabel: String,
        isStale: Bool = false
    ) {
        latestPhase = phase
        latestRegionTitle = regionTitle
        latestCheckedAt = checkedAt
        latestSourceLabel = sourceLabel
        latestIsStale = isStale
        reconcileActivity()
    }

    func endAll() {
        // Clients stay registered: a session ends when its scene says so, not when the driver
        // turns the activity off, so turning it back on finds CarPlay still connected.
        pipeline.enqueue { [weak self] in
            await self?.terminate(dismissal: .immediate)
        }
    }

    func settle() async {
        await pipeline.drain()
    }

    var canRunActivity: Bool {
        preference.isEnabled
            && liveActivityPermission.areActivitiesEnabled
    }

    private func insert(_ client: LiveActivitySessionClient) {
        clients.insert(client)
        reconcileActivity()
    }

    private func remove(_ client: LiveActivitySessionClient) {
        clients.remove(client)
        reconcileActivity()
    }

    private func reconcileActivity() {
        tokenSink?.liveActivitiesAllowedDidChange(canRunActivity)
        pipeline.enqueue { [weak self] in
            guard let self else { return }
            releaseIfEnded()
            let survivors = host.runningActivities()
            let shown = activity.map { [$0] } ?? survivors
            let action = LiveActivityLifecyclePolicy.nextAction(
                canRun: canRunActivity,
                phase: latestPhase,
                hasSession: !clients.isEmpty,
                hasActivity: activity != nil,
                hasSystemActivities: !survivors.isEmpty,
                isStale: latestIsStale,
                isNewerThanActivity: Self.isNewer(latestCheckedAt, than: shown.compactMap(\.checkedAt).max())
            )
            logDecision(action, systemActivities: survivors.count)
            switch action {
            case .none:
                break
            case .adopt:
                await adopt(from: survivors)
            case .endOrphans where canRunActivity:
                await endAllClear(survivors)
            case .endOrphans:
                await endSystemActivities(survivors)
            case .start:
                await startIfNeeded()
            case .update:
                await pushUpdate()
            case .terminate:
                // While activities may run, the policy terminates only on a confirmed all-clear.
                if canRunActivity, let held = activity {
                    fading = held
                    await terminate(dismissal: allClearDismissal())
                } else {
                    await terminate(dismissal: .immediate)
                }
            }
        }
    }

    private func adopt(from survivors: [any LiveActivityHandle]) async {
        // One the server can end goes first (AC-9).
        let ordered = survivors.filter(\.hasPushToken) + survivors.filter { !$0.hasPushToken }
        guard activity == nil, let adopted = ordered.first else { return }
        await removeFading(except: adopted.activityID)
        hold(adopted)
        // More than one can survive from builds that requested a duplicate on every launch.
        await endSystemActivities(Array(ordered.dropFirst()))
        await pushUpdate()
    }

    /// ALERT-push AC-9 (owner, 2026-11-10): an all-clear never just removes a red activity; it shows
    /// green for 5 minutes first, as the server's `end` push does.
    private func allClearDismissal() -> ActivityUIDismissalPolicy {
        .after(now().addingTimeInterval(LiveActivityLifecyclePolicy.allClearDisplayDuration))
    }

    private func endAllClear(_ survivors: [any LiveActivityHandle]) async {
        guard let first = survivors.first else { return }
        Self.log.info("ending \(survivors.count, privacy: .public) activities on an all-clear")
        fading = first
        await first.end(
            DriveCheckActivityContent(state: contentState(), staleDate: nil), dismissal: allClearDismissal())
        await endSystemActivities(Array(survivors.dropFirst()))
    }

    private func removeFading(except keptID: String?) async {
        guard let green = fading else { return }
        fading = nil
        if green.activityID != keptID {
            await green.end(nil, dismissal: .immediate)
        }
    }

    private func endSystemActivities(_ activities: [any LiveActivityHandle]) async {
        for orphan in activities {
            await orphan.end(nil, dismissal: .immediate)
        }
    }

    private func startIfNeeded() async {
        guard canRunActivity, activity == nil, !clients.isEmpty, latestPhase == .alarm else { return }
        await removeFading(except: nil)
        do {
            let content = currentContent()
            hold(try host.request(content))
            sentContent = SentContent(content)
        } catch {
            Self.log.error("Activity.request failed: \(String(describing: error), privacy: .public)")
        }
    }
}

extension LiveActivityController {
    /// Pushes may start an activity at any time, also while the app is not running; whatever the
    /// phase, the first one is held so its token reaches the server, and a second one is ended
    /// (ALERT-push AC-7, critic point 1). A held one the server cannot reach gives way (AC-9),
    /// and one that arrives while Live Activities are off is ended (REQ-SURF-008).
    private func receiveNewActivity(_ handle: any LiveActivityHandle) {
        pipeline.enqueue { [weak self] in
            guard let self else { return }
            // `activityUpdates` reports an activity late; by then it may have ended (`endAll`, an
            // all-clear), and holding a dead one would block the next request.
            guard handle.isRunning else {
                Self.log.info("new activity: already ended, ignored")
                return
            }
            guard canRunActivity else {
                if handle.activityID != activity?.activityID {
                    Self.log.info("new activity: ended, Live Activities not allowed")
                    await handle.end(nil, dismissal: .immediate)
                }
                return
            }
            releaseIfEnded()
            if let held = activity {
                guard held.activityID != handle.activityID else { return }
                guard !held.hasPushToken, handle.hasPushToken else {
                    Self.log.info("new activity: ended as a duplicate of the held one")
                    await handle.end(nil, dismissal: .immediate)
                    return
                }
                Self.log.info("new activity: replaces a held one the server cannot reach")
                release()
                await held.end(nil, dismissal: .immediate)
            }
            await removeFading(except: handle.activityID)
            Self.log.info("new activity: held, server can reach it: \(handle.hasPushToken, privacy: .public)")
            hold(handle)
        }
    }

    private func hold(_ handle: any LiveActivityHandle) {
        activity = handle
        sentContent = nil
        latestActivityToken = nil
        activityTokenTask?.cancel()
        let tokens = handle.pushTokens()
        activityTokenTask = Task { @MainActor [weak self] in
            for await token in tokens {
                // A token taken just before `release()` must not revive the ended activity's record.
                guard !Task.isCancelled else { break }
                self?.latestActivityToken = token
                self?.tokenSink?.activityTokenDidChange(token)
            }
        }
    }

    /// The system ends activities on its own (the server's `end` push, the time limit, a swipe);
    /// holding a dead one would end the next alarm's activity as a duplicate (AC-7).
    private func releaseIfEnded() {
        guard let held = activity, !held.isRunning else { return }
        release()
    }

    private func release() {
        activity = nil
        sentContent = nil
        latestActivityToken = nil
        activityTokenTask?.cancel()
        tokenSink?.activityTokenDidChange(nil)
    }

    /// BUG-LA-push-start: the device log shows every decision but the routine `none`.
    private func logDecision(_ action: LiveActivityLifecyclePolicy.Action, systemActivities: Int) {
        guard action != .none else { return }
        Self.log.info(
            """
            reconcile: \(String(describing: action), privacy: .public) \
            phase=\(self.latestPhase.rawValue, privacy: .public) \
            stale=\(self.latestIsStale, privacy: .public) \
            sessions=\(self.clients.count, privacy: .public) \
            held=\(self.activity != nil, privacy: .public) \
            system=\(systemActivities, privacy: .public)
            """)
    }

    /// `nil` app data is never newer; an activity with no time is always older.
    nonisolated static func isNewer(_ checkedAt: Date?, than shown: Date?) -> Bool {
        guard let checkedAt else { return false }
        guard let shown else { return true }
        return checkedAt >= shown
    }

    /// Several reconciles can run on the same content (a session change queued behind new content);
    /// only a change reaches ActivityKit. Unknown after adoption, so the first push always goes out.
    private func pushUpdate() async {
        guard let activity else { return }
        // The server may have written newer content (a push update); the app never overwrites it
        // with an older check or with no check at all.
        guard Self.isNewer(latestCheckedAt, than: activity.checkedAt) else { return }
        let content = currentContent()
        guard SentContent(content) != sentContent else { return }
        sentContent = SentContent(content)
        await activity.update(content)
    }

    private func terminate(dismissal: ActivityUIDismissalPolicy) async {
        guard let activity else { return }
        Self.log.info("ending the held activity, dismissal: \(String(describing: dismissal), privacy: .public)")
        release()
        await activity.end(DriveCheckActivityContent(state: contentState(), staleDate: nil), dismissal: dismissal)
    }

    private func currentContent() -> DriveCheckActivityContent {
        DriveCheckActivityContent(
            state: contentState(),
            staleDate: LiveActivityStaleDate.make(checkedAt: latestCheckedAt)
        )
    }

    private func contentState() -> DriveCheckActivityAttributes.ContentState {
        DriveCheckActivityAttributes.ContentState(
            phase: latestPhase,
            regionTitle: latestRegionTitle,
            checkedAt: latestCheckedAt,
            sourceLabel: latestSourceLabel,
            isStale: latestIsStale
        )
    }
}
