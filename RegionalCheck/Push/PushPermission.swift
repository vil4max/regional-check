import Foundation
import UIKit
import UserNotifications

enum PushPermissionStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case allowed
}

/// The app's notification settings as iOS has them, mirrored on Details (ALERT-push AC-14).
struct NotificationSystemSettings: Equatable, Sendable {
    var isAllowed: Bool
    var isTimeSensitiveOn: Bool
    var isScheduledSummaryOn: Bool

    static let unknown = NotificationSystemSettings(
        isAllowed: false, isTimeSensitiveOn: false, isScheduledSummaryOn: false)
}

protocol PushPermissionProviding: Sendable {
    func status() async -> PushPermissionStatus
    /// Asks iOS once; `true` when the driver allowed notifications.
    func request() async -> Bool
    func systemSettings() async -> NotificationSystemSettings
}

@MainActor
protocol RemoteNotificationRegistering: AnyObject {
    func registerForRemoteNotifications()
}

struct SystemPushPermission: PushPermissionProviding {
    func status() async -> PushPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .allowed
        }
    }

    func systemSettings() async -> NotificationSystemSettings {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationSystemSettings(
            isAllowed: [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus),
            isTimeSensitiveOn: settings.timeSensitiveSetting == .enabled,
            isScheduledSummaryOn: settings.scheduledDeliverySetting == .enabled
        )
    }

    func request() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}

@MainActor
final class SystemRemoteNotificationRegistrar: RemoteNotificationRegistering {
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
