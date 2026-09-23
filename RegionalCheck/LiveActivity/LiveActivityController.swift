// `@preconcurrency` because `ActivityKit.Activity` is a non-Sendable class whose `update` and `end`
// are nonisolated `async`, so Swift 6 reports calling them from this `@MainActor` type as sending a
// non-Sendable value. Safe here: the only `Activity` this type owns is `activity`, it is read and
// written on the main actor alone, and handing it to ActivityKit's own off-actor API is what that
// API is for. Scoped to this file — remove it once ActivityKit annotates `Activity`.
//
// Rechecked when orphan adoption was added (iOS 27.0 SDK): `Activity` is still declared without a
// `Sendable` conformance, and adoption adds more of the same calls — `end` on every activity read
// from `Activity.activities` — so the import can be neither narrowed nor removed yet.
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
    private(set) var clients: Set<LiveActivitySessionClient> = []
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
        // Clients stay registered: a session ends when its scene says so, not when the driver
        // turns the activity off, so turning it back on finds CarPlay still connected.
        pipeline.enqueue { [weak self] in
            await self?.terminate(dismissal: .immediate)
        }
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
            let survivors = systemActivities
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

    /// Live activities the system still shows for this app, including ones requested by a
    /// previous process. Ended ones stay listed until dismissed and cannot be updated, so they
    /// are not candidates. ActivityKit is not available to the unit-test host.
    private var systemActivities: [Activity<DriveCheckActivityAttributes>] {
        guard !HostProcess.isUnitTesting else { return [] }
        return Activity<DriveCheckActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    private func adopt(from survivors: [Activity<DriveCheckActivityAttributes>]) async {
        guard activity == nil, let adopted = survivors.first else { return }
        activity = adopted
        // More than one can survive from builds that requested a duplicate on every launch.
        await endSystemActivities(Array(survivors.dropFirst()))
        await pushUpdate()
    }

    private func endSystemActivities(_ activities: [Activity<DriveCheckActivityAttributes>]) async {
        for orphan in activities {
            await orphan.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func startIfNeeded() async {
        guard canRunActivity, activity == nil, !clients.isEmpty, latestPhase == .alarm else { return }
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
        LiveActivityStaleDate.make(checkedAt: latestCheckedAt)
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
