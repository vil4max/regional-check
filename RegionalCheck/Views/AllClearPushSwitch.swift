import SwiftUI

/// The rows of the Notifications section on Details (UI-simplify AC-7): the alert notice switch
/// (REQ-PUSH-001), which shows "on" only while iOS allows notifications (REQ-PUSH-005), then rows
/// that mirror iOS's notification settings for the app, in Apple's own words, each opening them
/// (ALERT-push AC-14, AC-15). The section around them carries the footer (REQ-PUSH-006).
struct AllClearPushSwitch: View {
    var push: PushRegistrationController
    var openSettings: () -> Void

    var body: some View {
        Toggle(
            "details.allClear.toggle",
            isOn: Binding(
                get: { push.isSwitchOn },
                set: { enabled in Task { await push.setEnabled(enabled) } }
            )
        )
        .tint(Color(uiColor: .systemGreen))
        SystemSettingRow(
            titleKey: "details.push.allowNotifications",
            valueKey: push.systemSettings.isAllowed ? "details.push.on" : "details.push.off",
            openSettings: openSettings)
        SystemSettingRow(
            titleKey: "details.push.timeSensitive",
            valueKey: push.systemSettings.isTimeSensitiveOn ? "details.push.on" : "details.push.off",
            openSettings: openSettings)
        SystemSettingRow(
            titleKey: "details.push.delivery",
            valueKey: push.systemSettings.isScheduledSummaryOn
                ? "details.push.delivery.scheduled" : "details.push.delivery.immediate",
            openSettings: openSettings)
    }
}

/// A Settings-style row: the setting's name, its value and a chevron; tapping opens the app's
/// notification settings, where the driver changes it (ALERT-push AC-14).
private struct SystemSettingRow: View {
    let titleKey: LocalizedStringKey
    let valueKey: LocalizedStringKey
    let openSettings: () -> Void

    var body: some View {
        Button(action: openSettings) {
            DetailsValueRow(title: Text(titleKey), value: Text(valueKey))
        }
    }
}
