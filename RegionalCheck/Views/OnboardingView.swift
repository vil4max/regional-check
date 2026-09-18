import SwiftUI

/// RD-16: the real first-launch screen (`docs/design/redesign/screens-onboarding-about-paywall.md`
/// §1). `MainTabView` shows this as a full-screen cover until "Get Started" is tapped, gated on
/// `hasCompletedOnboarding` — previously this view only rendered from the DEBUG screenshot phase
/// switch, never from the real app root (a failure condition this task closes).
///
/// `About` used to be a second `purpose` of this same view; it is now `AboutView`, a distinct
/// screen with its own layout (PRO/DATA sections), so this view no longer takes a purpose.
struct OnboardingView: View {
    var onContinue: () -> Void

    private struct Row: Identifiable {
        let id: String
        let systemImage: String
        let titleKey: LocalizedStringKey
        let captionKey: LocalizedStringKey
    }

    /// §1's three rows, in mockup order.
    private static let rows: [Row] = [
        Row(
            id: "carplay",
            systemImage: "steeringwheel",
            titleKey: "onboarding.row.carplay.title",
            captionKey: "onboarding.row.carplay.caption"
        ),
        Row(
            id: "location",
            systemImage: "location.fill",
            titleKey: "onboarding.row.location.title",
            captionKey: "onboarding.row.location.caption"
        ),
        Row(
            id: "free",
            systemImage: "checkmark.shield",
            titleKey: "onboarding.row.free.title",
            captionKey: "onboarding.row.free.caption"
        )
    ]

    var body: some View {
        ZStack {
            Theme.RedesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 116)

                heroMark
                    .padding(.bottom, Theme.RedesignHeroSizes.titleSpacing)

                Text("Drive Check")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Onboarding body")
                    .font(.system(size: 17, design: .rounded))
                    .lineSpacing(7)
                    .foregroundStyle(Theme.RedesignColors.textBody)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.horizontal, Theme.RedesignSpacing.screenInset)

                rowsCard
                    .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                    .padding(.top, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.xl)

                Button(action: onContinue) {
                    Text("Get Started")
                        .font(Theme.RedesignTypography.navTitle)
                        .foregroundStyle(Theme.RedesignColors.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Theme.RedesignColors.textPrimary,
                            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                        )
                }
                .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
                .accessibilityLabel(Text("Get Started"))
                .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                .padding(.bottom, 58)
            }
        }
    }

    /// The neutral launch mark (§1): same ring geometry as the live status hero, but a fixed
    /// idle tick color and a plain neutral dot — no status color at any point in onboarding.
    private var heroMark: some View {
        ZStack {
            Circle()
                .stroke(Theme.RedesignColors.ringIdleBase, lineWidth: Theme.RedesignHeroSizes.tickWidth)
                .frame(
                    width: Theme.RedesignHeroSizes.ringRadius * 2,
                    height: Theme.RedesignHeroSizes.ringRadius * 2
                )
            Circle()
                .fill(Theme.RedesignColors.textBody)
                .frame(width: 22, height: 22)
                .shadow(color: .white.opacity(0.07), radius: 18)
        }
        .frame(width: Theme.RedesignHeroSizes.ringDiameter, height: Theme.RedesignHeroSizes.ringDiameter)
        .accessibilityHidden(true)
    }

    private var rowsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(Theme.RedesignColors.separator)
                }
                onboardingRow(row)
            }
        }
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .fill(Theme.RedesignColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }

    private func onboardingRow(_ row: Row) -> some View {
        HStack(spacing: Theme.RedesignCardSizes.innerGap) {
            Image(systemName: row.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.titleKey)
                    .font(Theme.RedesignTypography.body.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                Text(row.captionKey)
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: Theme.RedesignRowSizes.grouped + 8)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Onboarding") {
    OnboardingView(onContinue: {})
}
