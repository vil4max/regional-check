import SwiftUI

/// The floating title row of a tab (`docs/tasks/redesign.md` §6.1 item 1): the title centered and
/// nothing else. REQ-SURF-007 removed the crown and the PRO chip; the About button went when the
/// Details tab absorbed the About screen (ADR 0015).
///
/// The row is the scroll view's `safeAreaBar`, so content scrolls under it and the system draws
/// the scroll edge effect behind the title. The row paints no backing of its own: an opaque one
/// read as a dark band and cut off the status ring's glow.
struct StatusToolbar: View {
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
    }

    private var titleRow: some View {
        Text(title)
            .font(Theme.RedesignTypography.navTitle)
            .foregroundStyle(Theme.RedesignColors.textPrimary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}
