import SwiftUI

/// RD-5: navigation row (`docs/tasks/redesign.md` §6.1 item 1) — round Pro button left, "Drive
/// Check" + PRO chip centered, round About button right. The crown stays for users with and
/// without Pro (owner ruling Q10).
///
/// The row is the scroll view's top safe-area inset (`StatusView`), so content scrolls under it.
/// Only the round buttons carry glass; the title has no surface of its own, so the row paints
/// the screen's background behind itself — through the top safe area — and fades it out just
/// below, which keeps the hero and summary from reading through "Drive Check".
struct StatusToolbar: View {
    /// Height of the fade drawn below the row. Zero under Reduce Transparency, where the backing
    /// ends in a hard edge instead of a translucent ramp.
    nonisolated static func fadeHeight(reduceTransparency: Bool) -> CGFloat {
        reduceTransparency ? 0 : Theme.RedesignSpacing.toolbarFade
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
        .background { backing }
    }

    /// Sized by the row itself: the solid part is the row's own bounds extended through the top
    /// safe area, and the fade hangs below those bounds, over the hero's top padding. Nothing
    /// here knows the row's height or the device's inset as a number.
    private var backing: some View {
        Theme.RedesignColors.background
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Theme.RedesignColors.background, Theme.RedesignColors.background.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: Self.fadeHeight(reduceTransparency: reduceTransparency))
                .alignmentGuide(.bottom) { $0[.top] }
            }
            .allowsHitTesting(false)
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
