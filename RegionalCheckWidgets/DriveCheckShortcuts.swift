import AppIntents
import DriveCheckKit

struct DriveCheckShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckAlertStatusIntent(),
            phrases: [
                "Check alert status in \(.applicationName)",
                "Check air raid status in \(.applicationName)",
                "Перевірити статус тривоги в \(.applicationName)",
                "Проверить статус тревоги в \(.applicationName)"
            ],
            shortTitle: "intent.check.shortTitle",
            systemImageName: "exclamationmark.circle"
        )
    }
}
