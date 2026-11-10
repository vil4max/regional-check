import SwiftUI

/// The first-launch screen. `MainTabView` shows it as a full-screen cover until "Continue" is
/// tapped, gated on `hasCompletedOnboarding`.
///
/// UI-simplify AC-9: Apple's welcome-sheet pattern — a large title, three feature rows with SF
/// Symbols in the tint colour, and one prominent "Continue" button pinned at the bottom, outside
/// the scroll view, so onboarding can be completed at every text size.
struct OnboardingView: View {
    var onContinue: () -> Void

    private struct Feature: Identifiable {
        let id: String
        let systemImage: String
        let titleKey: LocalizedStringKey
        let captionKey: LocalizedStringKey
    }

    private static let features: [Feature] = [
        Feature(
            id: "carplay",
            systemImage: "car.fill",
            titleKey: "onboarding.row.carplay.title",
            captionKey: "onboarding.row.carplay.caption"
        ),
        Feature(
            id: "location",
            systemImage: "location.fill",
            titleKey: "onboarding.row.location.title",
            captionKey: "onboarding.row.location.caption"
        ),
        Feature(
            id: "free",
            systemImage: "checkmark.shield.fill",
            titleKey: "onboarding.row.free.title",
            captionKey: "onboarding.row.free.caption"
        ),
    ]

    /// The symbol column, scaled with the text so the rows stay aligned at every size.
    @ScaledMetric(relativeTo: .title) private var symbolWidth: CGFloat = 44

    var body: some View {
        // The proxy reports the height left above the pinned button, so a short screen gives up
        // the top spacing first (DUO AC-1).
        GeometryReader { proxy in
            ScrollView {
                content(topSpacing: OnboardingLayout.topSpacing(availableHeight: proxy.size.height))
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: onContinue) {
                Text("onboarding.continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .background(Theme.RedesignColors.background.ignoresSafeArea(edges: .bottom))
        }
        .background(Theme.RedesignColors.background.ignoresSafeArea())
    }

    private func content(topSpacing: CGFloat) -> some View {
        VStack(spacing: 40) {
            Text("onboarding.title")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, topSpacing)

            VStack(alignment: .leading, spacing: 28) {
                ForEach(Self.features) { feature($0) }
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }

    private func feature(_ feature: Feature) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: feature.systemImage)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.titleKey)
                    .font(.headline)
                Text(feature.captionKey)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The space above the welcome title. The design's spacing holds wherever the space above the
/// pinned button is at least `designAvailableHeight`, which iPhone 16 and iPhone 17 both have; a
/// shorter screen, such as the iPhone Duo's outer display (about 526 pt), gives up this spacing
/// first, down to `compactTopSpacing`, so the feature rows stay above the button.
enum OnboardingLayout {
    static let designTopSpacing: CGFloat = 72
    static let compactTopSpacing: CGFloat = Theme.Spacing.lg
    static let designAvailableHeight: CGFloat = 640

    static func topSpacing(availableHeight: CGFloat) -> CGFloat {
        let missing = max(0, designAvailableHeight - availableHeight)
        return max(compactTopSpacing, designTopSpacing - missing)
    }
}

#Preview("Onboarding") {
    OnboardingView(onContinue: {})
}

// The content is taller than the screen here; "Continue" must still be fully visible.
#Preview("Onboarding AX5") {
    OnboardingView(onContinue: {})
        .dynamicTypeSize(.accessibility5)
}
