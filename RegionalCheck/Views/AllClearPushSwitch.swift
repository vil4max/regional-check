import SwiftUI

/// The all-clear notice switch of the Details tab (REQ-PUSH-001). It shows "on" only while iOS
/// allows notifications (REQ-PUSH-005), and says what leaves the device (REQ-PUSH-006).
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
                HStack(alignment: .firstTextBaseline, spacing: Theme.RedesignCardSizes.innerGap) {
                    Text("details.allClear.systemOff")
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.statusStale)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("location.access.open_settings", action: openSettings)
                        .font(Theme.RedesignTypography.caption.weight(.semibold))
                        .foregroundStyle(Theme.RedesignColors.statusStale)
                        .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
                }
                .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(.vertical, Theme.RedesignCardSizes.innerGap)
    }
}
