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
    private let pipeline = LiveActivitySerialPipeline()
    private(set) var clients: Set<LiveActivitySessionClient> = []
    private var activity: (any LiveActivityHandle)?
    private var sentContent: SentContent?
    private var latestPhase: DriveCheckActivityPhase = .idle
    private var latestRegionTitle = ""
    private var latestCheckedAt: Date?
    private var latestSourceLabel = ""
    private var latestIsStale = false
    private var entitlementObservationTask: Task<Void, Never>?
    private var preferenceObservationTask: Task<Void, Never>?
    private var permissionObservationTask: Task<Void, Never>?

    init(
        preference: any LiveActivityPreferenceReading,
        entitlementChanges: @escaping () -> AsyncStream<Void> = { AsyncStream { $0.finish() } },
        liveActivityPermission: any LiveActivityPermissionSource,
        host: any LiveActivityHosting
    ) {
        self.preference = preference
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
    }

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
        pipeline.enqueue { [weak self] in
            guard let self else { return }
            let survivors = host.runningActivities()
            let action = LiveActivityLifecyclePolicy.nextAction(
                canRun: canRunActivity,
                phase: latestPhase,
                hasSession: !clients.isEmpty,
                hasActivity: activity != nil,
                hasSystemActivities: !survivors.isEmpty
            )
            switch action {
            case .none:
                break
            case .adopt:
                await adopt(from: survivors)
            case .endOrphans:
                await endSystemActivities(survivors)
            case .start:
                await startIfNeeded()
            case .update:
                await pushUpdate()
            case .terminate:
                await terminate(dismissal: .immediate)
            }
        }
    }

    private func adopt(from survivors: [any LiveActivityHandle]) async {
        guard activity == nil, let adopted = survivors.first else { return }
        activity = adopted
        sentContent = nil
        // More than one can survive from builds that requested a duplicate on every launch.
        await endSystemActivities(Array(survivors.dropFirst()))
        await pushUpdate()
    }

    private func endSystemActivities(_ activities: [any LiveActivityHandle]) async {
        for orphan in activities {
            await orphan.end(nil, dismissal: .immediate)
        }
    }

    private func startIfNeeded() async {
        guard canRunActivity, activity == nil, !clients.isEmpty, latestPhase == .alarm else { return }
        do {
            let content = currentContent()
            activity = try host.request(content)
            sentContent = SentContent(content)
        } catch {
            Self.log.error("Activity.request failed: \(String(describing: error), privacy: .public)")
        }
    }
}

extension LiveActivityController {
    /// Several reconciles can run on the same content (a session change queued behind new content);
    /// only a change reaches ActivityKit. Unknown after adoption, so the first push always goes out.
    private func pushUpdate() async {
        guard let activity else { return }
        let content = currentContent()
        guard SentContent(content) != sentContent else { return }
        sentContent = SentContent(content)
        await activity.update(content)
    }

    private func terminate(dismissal: ActivityUIDismissalPolicy) async {
        guard let activity else { return }
        self.activity = nil
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
