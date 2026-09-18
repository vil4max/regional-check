import SwiftUI

/// RD-5: navigation row (`docs/tasks/redesign.md` §6.1 item 1) — round Pro button left, "Drive
/// Check" + PRO chip centered, round About button right. The crown stays for users with and
/// without Pro (owner ruling Q10).
struct StatusToolbar: View {
    var isPro: Bool
    var onShowPaywall: (() -> Void)?
    var onShowInfo: (() -> Void)?
    var debugExplanationTraces: ExplanationTraceStore?
    @Binding var showsDebugTraces: Bool

    var body: some View {
        HStack {
            if let onShowPaywall {
                Button(action: onShowPaywall) {
                    Image(systemName: isPro ? "crown.fill" : "crown")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.RedesignColors.proAccent)
                        .frame(
                            width: Theme.RedesignControlSizes.navButton,
                            height: Theme.RedesignControlSizes.navButton
                        )
                        .redesignGlassSurface(in: Circle())
                        .overlay(Circle().strokeBorder(Theme.RedesignColors.buttonStroke, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
                .accessibilityLabel(Text(isPro ? "subscription.badge.pro" : "subscription.paywall.open"))
            }

            Spacer()

            titleRow

            Spacer()

            #if DEBUG
                if AppLaunchArguments.showExplanationTraces, debugExplanationTraces != nil {
                    Button {
                        showsDebugTraces = true
                    } label: {
                        Image(systemName: "ant")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.RedesignColors.textSecondary)
                            .frame(
                                width: Theme.RedesignControlSizes.navButton,
                                height: Theme.RedesignControlSizes.navButton
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
                    .accessibilityLabel(Text("AI explanation traces"))
                }
            #endif

            if let onShowInfo {
                Button(action: onShowInfo) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                        .frame(
                            width: Theme.RedesignControlSizes.navButton,
                            height: Theme.RedesignControlSizes.navButton
                        )
                        .redesignGlassSurface(in: Circle())
                        .overlay(Circle().strokeBorder(Theme.RedesignColors.buttonStroke, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
                .accessibilityLabel(Text("About"))
            }
        }
        .padding(.horizontal, Theme.RedesignSpacing.screenInset)
        .padding(.top, Theme.Spacing.sm)
    }

    private var titleRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("Drive Check")
                .font(Theme.RedesignTypography.navTitle)
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .lineLimit(1)

            if isPro {
                Text("Pro")
                    .font(Theme.RedesignTypography.proChip)
                    .tracking(Theme.RedesignTypography.proChipTracking)
                    .foregroundStyle(Theme.RedesignColors.proAccent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Theme.RedesignColors.proAccent.opacity(0.16), in: Capsule())
                    .accessibilityLabel(Text("subscription.badge.pro"))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
