// `@preconcurrency` because `ActivityKit.Activity` is a non-Sendable class whose `update` and `end`
// are nonisolated `async`, so Swift 6 reports calling them from this `@MainActor` type as sending a
// non-Sendable value. Safe here: the only `Activity` this type owns is `activity`, it is read and
// written on the main actor alone, and handing it to ActivityKit's own off-actor API is what that
// API is for. Scoped to this file — remove it once ActivityKit annotates `Activity`.
@preconcurrency import ActivityKit
import DriveCheckKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class LiveActivityController: LiveActivityControlling {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "LiveActivity")

    private let allowsLiveActivity: () -> Bool
    private let pipeline = LiveActivitySerialPipeline()
    private var clients: Set<LiveActivitySessionClient> = []
    private var activity: Activity<DriveCheckActivityAttributes>?
    private var latestPhase: DriveCheckActivityPhase = .idle
    private var latestRegionTitle = ""
    private var latestCheckedAt: Date?
    private var latestSourceLabel = ""
    private var latestIsStale = false
    private var entitlementObservationTask: Task<Void, Never>?

    init(
        allowsLiveActivity: @escaping () -> Bool,
        entitlementChanges: @escaping () -> AsyncStream<Void>
    ) {
        self.allowsLiveActivity = allowsLiveActivity
        entitlementObservationTask = Task { @MainActor [weak self] in
            for await _ in entitlementChanges() {
                self?.reconcileActivity()
            }
        }
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
        clients.removeAll()
        reconcileActivity()
    }

    private var canRunActivity: Bool {
        allowsLiveActivity()
            && ActivityAuthorizationInfo().areActivitiesEnabled
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
            let action = LiveActivityLifecyclePolicy.nextAction(
                canRun: canRunActivity,
                hasClients: !clients.isEmpty,
                hasActivity: activity != nil
            )
            switch action {
            case .none:
                break
            case .start:
                await startIfNeeded()
            case .update:
                await pushUpdate()
            case .terminate:
                await terminate(dismissal: .immediate)
            }
        }
    }

    private func startIfNeeded() async {
        guard canRunActivity, activity == nil, !clients.isEmpty else { return }
        let attributes = DriveCheckActivityAttributes()
        let state = contentState()
        let content = ActivityContent(
            state: state,
            staleDate: activityStaleDate
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            Self.log.error("Activity.request failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func pushUpdate() async {
        guard let activity else { return }
        let content = ActivityContent(
            state: contentState(),
            staleDate: activityStaleDate
        )
        await activity.update(content)
    }

    private func terminate(dismissal: ActivityUIDismissalPolicy) async {
        guard let activity else { return }
        self.activity = nil
        let content = ActivityContent(state: contentState(), staleDate: nil)
        await activity.end(content, dismissalPolicy: dismissal)
    }

    private var activityStaleDate: Date {
        LiveActivityStaleDate.make(
            checkedAt: latestCheckedAt,
            refreshInterval: RefreshPolicy.baselineSeconds
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
