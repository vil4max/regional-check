import SwiftUI

/// The alert notice switch of the Details tab (REQ-PUSH-001). It shows "on" only while iOS
/// allows notifications (REQ-PUSH-005), and says what leaves the device (REQ-PUSH-006). Under it,
/// the opt-in to Time Sensitive delivery and the system's real state, in Apple's own words
/// (ALERT-push AC-13..AC-15).
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

            if push.isBlockedBySystem {
                SystemStateRow(titleKey: "details.push.allowNotifications", openSettings: openSettings)
            }

            if push.isSwitchOn {
                timeSensitiveSwitch
                if push.showsTimeSensitiveOff {
                    SystemStateRow(titleKey: "details.push.timeSensitive", openSettings: openSettings)
                }
            }
        }
        .padding(.vertical, Theme.RedesignCardSizes.innerGap)
    }

    private var timeSensitiveSwitch: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(
                isOn: Binding(
                    get: { push.isUrgent },
                    set: { urgent in Task { await push.setUrgent(urgent) } }
                )
            ) {
                HStack(spacing: Theme.RedesignCardSizes.innerGap) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .frame(width: 22)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                        .accessibilityHidden(true)
                    Text("details.push.timeSensitive")
                        .font(Theme.RedesignTypography.body)
                        .foregroundStyle(Theme.RedesignColors.textPrimary)
                }
            }
            .tint(Theme.RedesignColors.statusClear)

            Text("details.push.timeSensitive.caption")
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)
        }
        .padding(.top, Theme.Spacing.sm)
    }
}

/// "<setting> · Off" with Open Settings, as iOS words it (ALERT-push AC-14, AC-15).
private struct SystemStateRow: View {
    let titleKey: LocalizedStringKey
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(titleKey)
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                Spacer(minLength: Theme.Spacing.sm)
                Text("details.push.off")
                    .foregroundStyle(Theme.RedesignColors.statusStale)
            }
            .font(Theme.RedesignTypography.caption)
            .accessibilityElement(children: .combine)
            Button("location.access.open_settings", action: openSettings)
                .font(Theme.RedesignTypography.caption.weight(.semibold))
                .foregroundStyle(Theme.RedesignColors.statusClear)
                .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
        }
        .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)
        .padding(.top, Theme.Spacing.sm)
    }
}
