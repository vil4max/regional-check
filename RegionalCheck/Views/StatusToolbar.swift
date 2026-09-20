import SwiftUI

/// The floating title row of a tab (`docs/tasks/redesign.md` §6.1 item 1): the title centered and
/// nothing else. REQ-SURF-007 removed the crown and the PRO chip; the About button went when the
/// Details tab absorbed the About screen (ADR 0015).
///
/// The row is the scroll view's top safe-area inset, so content scrolls under it. The title has
/// no surface of its own, so the row paints the screen's background behind itself — through the
/// top safe area — and fades it out just below, which keeps content from reading through it.
struct StatusToolbar: View {
    /// Height of the fade drawn below the row. Zero under Reduce Transparency, where the backing
    /// ends in a hard edge instead of a translucent ramp.
    nonisolated static func fadeHeight(reduceTransparency: Bool) -> CGFloat {
        reduceTransparency ? 0 : Theme.RedesignSpacing.toolbarFade
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var title: LocalizedStringKey = "Drive Check"
    var debugExplanationTraces: ExplanationTraceStore?
    var showsDebugTraces: Binding<Bool> = .constant(false)

    var body: some View {
        HStack {
            Spacer()

            titleRow

            Spacer()

            #if DEBUG
                if AppLaunchArguments.showExplanationTraces, debugExplanationTraces != nil {
                    Button {
                        showsDebugTraces.wrappedValue = true
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
        Text(title)
            .font(Theme.RedesignTypography.navTitle)
            .foregroundStyle(Theme.RedesignColors.textPrimary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}
