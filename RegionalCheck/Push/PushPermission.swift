import Foundation
import UIKit
import UserNotifications

enum PushPermissionStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case allowed
}

protocol PushPermissionProviding: Sendable {
    func status() async -> PushPermissionStatus
    /// Asks iOS once; `true` when the driver allowed notifications.
    func request() async -> Bool
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
