#if DEBUG
    import Foundation

    /// The notice switch for previews and snapshots: iOS allows notifications and the switch is on,
    /// with no permission prompt, APNs registration or network (REQ-PUSH-001, ALERT-push AC-14).
    @MainActor
    extension PushRegistrationController {
        static func fixture(
            regions: any PushRegionProviding,
            system: NotificationSystemSettings = NotificationSystemSettings(
                isAllowed: true, isTimeSensitiveOn: true, isScheduledSummaryOn: false),
            defaultsSuite: String = "vil4max.RegionalCheck.fixture.push"
        ) -> PushRegistrationController {
            let defaults = UserDefaults(suiteName: defaultsSuite) ?? .standard
            defaults.removePersistentDomain(forName: defaultsSuite)
            let store = PushPreferenceStore(defaults: defaults)
            store.isEnabled = true
            let controller = PushRegistrationController(
                regions: regions,
                permission: FixturePushPermission(system: system),
                registrar: FixtureRemoteNotificationRegistrar(),
                client: FixturePushClient(),
                store: store
            )
            controller.showFixtureSystemState(system)
            return controller
        }
    }

    struct FixturePushPermission: PushPermissionProviding {
        let system: NotificationSystemSettings

        func status() async -> PushPermissionStatus {
            system.isAllowed ? .allowed : .denied
        }

        func request() async -> Bool {
            system.isAllowed
        }

        func systemSettings() async -> NotificationSystemSettings {
            system
        }
    }

    @MainActor
    final class FixtureRemoteNotificationRegistrar: RemoteNotificationRegistering {
        func registerForRemoteNotifications() {}
    }

    struct FixturePushClient: PushRegistrationSending {
        func put(_: PushRegistration) async throws {}
        func delete(token _: String) async throws {}
    }
#endif
