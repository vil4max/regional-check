import SwiftUI

/// RD-16: the outside-Ukraine sheet (`docs/design/redesign/screens-onboarding-about-paywall.md`
/// §4, REQ-REGION-008). `MainTabView` presents this from `RegionSelection.shouldShowOutsideUkraineSheet`
/// — not, as before, from a "seen once ever" flag unrelated to actual location (the failure
/// condition this task closes).
struct OutsideUkraineInfoSheet: View {
    var onDismiss: () -> Void
    var onChooseRegion: () -> Void

    private enum Metrics {
        static let sheetHeight: CGFloat = 420
        static let bottomInset: CGFloat = 16
        static let buttonHeight: CGFloat = 56
        static let mapOpacity: CGFloat = 0.22
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Theme.RedesignColors.background

                Image("OutsideUkraineMap")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .opacity(Metrics.mapOpacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [
                        Theme.RedesignColors.background.opacity(0.35),
                        Theme.RedesignColors.background.opacity(0.05),
                        Theme.RedesignColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    icon
                        .padding(.top, Theme.Spacing.lg)

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("outsideUkraine.sheetTitle")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.RedesignColors.textPrimary)

                        Text("outsideUkraine.sheetBody")
                            .font(.system(size: 17, design: .rounded))
                            .lineSpacing(6)
                            .foregroundStyle(Theme.RedesignColors.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Theme.Spacing.md)

                    Spacer(minLength: Theme.Spacing.md)

                    Button(action: onDismiss) {
                        Text("Got It")
                            .font(Theme.RedesignTypography.navTitle)
                            .foregroundStyle(Theme.RedesignColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: Metrics.buttonHeight)
                            .background(
                                Theme.RedesignColors.textPrimary,
                                in: RoundedRectangle(cornerRadius: Metrics.buttonHeight / 2, style: .continuous)
                            )
                    }
                    .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))

                    Button(action: onChooseRegion) {
                        Text("outsideUkraine.chooseRegion")
                            .font(Theme.RedesignTypography.body.weight(.semibold))
                            .foregroundStyle(Theme.RedesignColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.RedesignControlSizes.navButton)
                    }
                    .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
                    .padding(.top, 2)
                }
                .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                .padding(.bottom, Metrics.bottomInset)
                .frame(width: width, height: height, alignment: .top)
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.sheetHeight)
        .presentationDetents([.height(Metrics.sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Theme.RedesignColors.background)
        .presentationSizing(.page)
    }

    private var icon: some View {
        Image(systemName: "location.slash")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.RedesignColors.textPrimary)
            .frame(width: Theme.RedesignControlSizes.navButton, height: Theme.RedesignControlSizes.navButton)
            .background(Color.white.opacity(0.08), in: Circle())
            .accessibilityHidden(true)
    }
}

#Preview("Outside Ukraine") {
    // Not wrapped in an actual `.sheet` — Prefire's synchronous capture runs before a real
    // sheet's presentation transition settles and would snapshot a blank frame; the
    // `.presentation*` modifiers above are harmless no-ops outside a live presentation.
    //
    // The sheet's own `GeometryReader` only paints `Theme.RedesignColors.background` within its
    // fixed-height card (real sheet presentations show the dimmed parent content above/below it),
    // so outside a live presentation the rest of the snapshot canvas is the host window's own
    // default — which the app's `.preferredColorScheme(.dark)` (RegionalCheckApp.swift) can
    // change out from under an ambient-canvas baseline. Filling it explicitly here keeps the
    // baseline asserting the app's own background, not whatever the host defaults to.
    OutsideUkraineInfoSheet(onDismiss: {}, onChooseRegion: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.RedesignColors.background)
}
