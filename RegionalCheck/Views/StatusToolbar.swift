import SwiftUI

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
                        .font(Theme.Typography.refreshSymbol)
                        .foregroundStyle(isPro ? Theme.Colors.onboarding : Theme.Colors.onFillSecondary)
                        .frame(width: Theme.Spacing.refreshControl, height: Theme.Spacing.refreshControl)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
                .accessibilityLabel(Text(isPro ? "subscription.badge.pro" : "subscription.paywall.open"))
            }

            Spacer()

            #if DEBUG
                if AppLaunchArguments.showExplanationTraces, debugExplanationTraces != nil {
                    Button {
                        showsDebugTraces = true
                    } label: {
                        Image(systemName: "ant")
                            .font(Theme.Typography.refreshSymbol)
                            .foregroundStyle(Theme.Colors.onFillSecondary)
                            .frame(width: Theme.Spacing.refreshControl, height: Theme.Spacing.refreshControl)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
                    .accessibilityLabel(Text("AI explanation traces"))
                }
            #endif

            if let onShowInfo {
                Button(action: onShowInfo) {
                    Image(systemName: "info.circle")
                        .font(Theme.Typography.refreshSymbol)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                        .frame(width: Theme.Spacing.refreshControl, height: Theme.Spacing.refreshControl)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
                .accessibilityLabel(Text("About"))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }
}
