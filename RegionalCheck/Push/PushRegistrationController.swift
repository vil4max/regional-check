import DriveCheckKit
import Foundation
import Observation
import os

/// The region the server may be told: set by location inside Ukraine or by the driver's own
/// choice, never the Kyiv fallback of a first launch without either (REQ-PUSH-004).
@MainActor
protocol PushRegionProviding: AnyObject {
    var pushEligibleRegion: AlertRegion? { get }
}

/// The all-clear push opt-in (REQ-PUSH-001...007): permission, the APNs token, and keeping the
/// server's record of token and region in step with this device.
@MainActor
@Observable
final class PushRegistrationController {
    private static let log = Logger(subsystem: "vil4max.RegionalCheck", category: "Push")

    private let regions: any PushRegionProviding
    private let permission: any PushPermissionProviding
    private let registrar: any RemoteNotificationRegistering
    private let client: any PushRegistrationSending
    private let store: PushPreferenceStore
    private let locale: () -> Locale
    private let environment: PushRegistration.Environment
    private let now: () -> Date
    private var syncTail: Task<Void, Never>?
    private var isObservingRegion = false

    /// Refreshed weekly, far inside the server's 60-day expiry.
    static let refreshInterval: TimeInterval = 7 * 24 * 3600

    private(set) var permissionStatus: PushPermissionStatus = .notDetermined
    private(set) var isEnabled: Bool
    private(set) var isUrgent: Bool
    private(set) var isTimeSensitiveAllowed = true
    /// Tells the Live Activity record to follow the Time Sensitive and notice switches (AC-13).
    @ObservationIgnored var onUrgentChange: (() -> Void)?

    init(
        regions: any PushRegionProviding,
        permission: any PushPermissionProviding = SystemPushPermission(),
        registrar: any RemoteNotificationRegistering = SystemRemoteNotificationRegistrar(),
        client: any PushRegistrationSending = URLSessionPushRegistrationClient(),
        store: PushPreferenceStore = PushPreferenceStore(),
        locale: @escaping () -> Locale = { .current },
        environment: PushRegistration.Environment = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.regions = regions
        self.permission = permission
        self.registrar = registrar
        self.client = client
        self.store = store
        self.locale = locale
        self.environment = environment
        self.now = now
        isEnabled = store.isEnabled
        isUrgent = store.isUrgent
    }

    /// What the switch shows: never "on" while iOS refuses notifications (REQ-PUSH-005).
    var isSwitchOn: Bool {
        isEnabled && permissionStatus == .allowed
    }

    var isBlockedBySystem: Bool {
        permissionStatus == .denied
    }

    /// The driver's switch. Asks iOS for permission the first time only; a refusal leaves the
    /// switch off and nothing registered.
    func setEnabled(_ enabled: Bool) async {
        if enabled {
            permissionStatus = await permission.status()
            if permissionStatus == .notDetermined {
                permissionStatus = await permission.request() ? .allowed : .denied
            }
            guard permissionStatus == .allowed else {
                isEnabled = false
                store.isEnabled = false
                return
            }
            isEnabled = true
            store.isEnabled = true
            registrar.registerForRemoteNotifications()
        } else {
            isEnabled = false
            store.isEnabled = false
        }
        onUrgentChange?()
        await sync()
    }

    func didRegister(deviceToken: Data) async {
        store.token = PushRegistration.tokenString(from: deviceToken)
        await sync()
    }

    func didFailToRegister(error: Error) {
        Self.log.error("remote notification registration failed: \(error.localizedDescription, privacy: .public)")
    }

    /// On every foreground: follows the system permission, refreshes the token and retries
    /// whatever failed offline.
    func sceneDidBecomeActive() async {
        permissionStatus = await permission.status()
        isTimeSensitiveAllowed = await permission.timeSensitiveAllowed()
        if isEnabled && permissionStatus == .allowed {
            registrar.registerForRemoteNotifications()
        }
        await sync()
    }

    /// Brings the server in step: a delete when off, revoked or the token changed; a put when the
    /// region, language or token differs from what the server last heard.
    func sync() async {
        await enqueueSync().value
    }

    /// One sync at a time: each reads what the previous wrote, so an opt-out during a request in
    /// flight cannot be overtaken by it (REQ-PUSH-003). Queued synchronously, so `idle()` sees it.
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

    /// Returns when every sync queued so far has finished; for tests and orderly shutdown.
    func idle() async {
        await syncTail?.value
    }

    private func performSync() async {
        // Read every time: a CarPlay-only launch never runs the phone's foreground hook, and a
        // stale "not determined" would make an opted-in device look revoked (REQ-PUSH-005).
        permissionStatus = await permission.status()
        isTimeSensitiveAllowed = await permission.timeSensitiveAllowed()
        if let stale = store.pendingDeleteToken {
            if (try? await client.delete(token: stale)) != nil {
                store.pendingDeleteToken = nil
            }
        }
        guard isEnabled, permissionStatus == .allowed else {
            await forgetCurrentToken()
            return
        }
        guard let token = store.token, let region = regions.pushEligibleRegion else { return }
        let registration = PushRegistration(
            token: token,
            region: region.rawValue,
            env: environment.rawValue,
            lang: PushRegistration.language(for: locale()),
            urgent: isUrgent ? true : nil
        )
        let isCurrent = registration == store.lastSent
        let sentAt = store.lastSentAt ?? .distantPast
        guard !isCurrent || now().timeIntervalSince(sentAt) >= Self.refreshInterval else { return }
        if let previous = store.lastSent, previous.token != token {
            store.pendingDeleteToken = previous.token
        }
        do {
            try await client.put(registration)
            store.lastSent = registration
            store.lastSentAt = now()
        } catch {
            Self.log.error("registration failed, retrying on the next foreground")
        }
    }

    private func forgetCurrentToken() async {
        guard let sent = store.lastSent else { return }
        do {
            try await client.delete(token: sent.token)
            store.lastSent = nil
        } catch {
            store.pendingDeleteToken = sent.token
            store.lastSent = nil
        }
    }

}

/// ALERT-push AC-13, AC-14: the opt-in to Time Sensitive delivery and what iOS allows.
extension PushRegistrationController {
    /// The Time Sensitive row: the driver asked for it, but iOS has it off for the app (AC-14).
    var showsTimeSensitiveOff: Bool {
        isSwitchOn && isUrgent && !isTimeSensitiveAllowed
    }

    /// The driver's Time Sensitive switch, off by default (AC-13).
    func setUrgent(_ urgent: Bool) async {
        isUrgent = urgent
        store.isUrgent = urgent
        onUrgentChange?()
        await sync()
    }
}

/// Region changes reach the server whichever scene launched the app (REQ-PUSH-001).
extension PushRegistrationController {
    /// Starts the region observer once; a phone launch and a CarPlay-only launch both call it.
    func startObservingRegionChanges() {
        guard !isObservingRegion else { return }
        observeRegionChanges()
        // Every launch, whichever scene started it, brings the server in step and refreshes a
        // week-old registration.
        enqueueSync()
    }

    /// Re-syncs whenever the eligible region changes.
    func observeRegionChanges() {
        isObservingRegion = true
        withObservationTracking {
            _ = regions.pushEligibleRegion
        } onChange: { [weak self] in
            Task { @MainActor in
                await self?.sync()
                self?.observeRegionChanges()
            }
        }
    }
}
