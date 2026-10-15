import SwiftUI

/// The floating title row of a tab: the title centered and, on Status, the Pro crown (ADR 0016):
/// an outline that opens the Pro sheet, filled gold for an owner.
///
/// The row is the scroll view's `safeAreaBar`, so content scrolls under it and the system draws
/// the scroll edge effect behind the title. The row paints no backing of its own: an opaque one
/// read as a dark band and cut off the status ring's glow.
struct StatusToolbar: View {
    var title: LocalizedStringKey = "Drive Check"
    var isProOwner = false
    var onOpenPro: (() -> Void)?
    var debugExplanationTraces: ExplanationTraceStore?
    var showsDebugTraces: Binding<Bool> = .constant(false)

    var body: some View {
        HStack {
            if onOpenPro != nil {
                // Balances the crown so the title stays centred.
                Color.clear.frame(width: Theme.RedesignControlSizes.navButton, height: 1)
            }

            Spacer()

            titleRow

            Spacer()

            if let onOpenPro {
                crownButton(action: onOpenPro)
            }

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

    private func crownButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isProOwner ? "crown.fill" : "crown")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isProOwner ? Theme.RedesignColors.proAccent : Theme.RedesignColors.textSecondary)
                .frame(width: Theme.RedesignControlSizes.navButton, height: Theme.RedesignControlSizes.navButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
        .accessibilityLabel(Text("Drive Check Pro"))
        .accessibilityValue(isProOwner ? Text("pro.crown.owned") : Text(verbatim: ""))
    }

    private var titleRow: some View {
        Text(title)
            .font(Theme.RedesignTypography.navTitle)
            .foregroundStyle(Theme.RedesignColors.textPrimary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}
