import SwiftUI

/// The alert notice switch of the Details tab (REQ-PUSH-001). It shows "on" only while iOS
/// allows notifications (REQ-PUSH-005), and says what leaves the device (REQ-PUSH-006). Under it,
/// rows that mirror iOS's notification settings for the app, in Apple's own words, each opening
/// them (ALERT-push AC-14, AC-15).
struct AllClearPushSwitch: View {
    var push: PushRegistrationController
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                isOn: Binding(
                    get: { push.isSwitchOn },
                    set: { enabled in Task { await push.setEnabled(enabled) } }
                )
            ) {
                HStack(spacing: Theme.RedesignCardSizes.innerGap) {
                    Image(systemName: "bell")
                        .frame(width: 22)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                        .accessibilityHidden(true)
                    Text("details.allClear.toggle")
                        .font(Theme.RedesignTypography.body)
                        .foregroundStyle(Theme.RedesignColors.textPrimary)
                }
            }
            .tint(Theme.RedesignColors.statusClear)

            Text("details.allClear.caption")
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)

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
        .padding(.vertical, Theme.RedesignCardSizes.innerGap)
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
            HStack(spacing: Theme.Spacing.sm) {
                Text(titleKey)
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                Spacer(minLength: Theme.Spacing.sm)
                Text(valueKey)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .lineLimit(1)
                    .layoutPriority(1)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textSecondary.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .font(Theme.RedesignTypography.body)
            .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)
            .padding(.top, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
