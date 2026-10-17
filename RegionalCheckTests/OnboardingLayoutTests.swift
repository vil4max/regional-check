import CoreGraphics
@testable import RegionalCheck
import Testing

/// The onboarding stack keeps the design's top spacing on the phones it was drawn for and gives
/// that spacing up first on a shorter screen, such as the iPhone Duo's outer display, so the rows
/// card stays above the pinned "Get Started" bar.
struct OnboardingLayoutTests {
    @Test("DUO AC-1 onboarding keeps the design's top spacing on iPhone 16 and iPhone 17 heights")
    func designHeightsKeepTheDesignSpacing() {
        // Space above the pinned bar: iPhone 16 852 − 59 − 34 − 114, iPhone 17 874 − 62 − 34 − 114.
        #expect(OnboardingLayout.topSpacing(availableHeight: 645) == OnboardingLayout.designTopSpacing)
        #expect(OnboardingLayout.topSpacing(availableHeight: 664) == OnboardingLayout.designTopSpacing)
    }

    @Test("DUO AC-1 onboarding takes a shorter screen's missing height out of the top spacing")
    func shortScreenShrinksTheTopSpacing() {
        let missing: CGFloat = 40
        let height = OnboardingLayout.designAvailableHeight - missing
        #expect(OnboardingLayout.topSpacing(availableHeight: height) == OnboardingLayout.designTopSpacing - missing)
    }

    @Test("DUO AC-1 onboarding never shrinks the top spacing below the compact spacing")
    func duoOuterDisplayUsesTheCompactSpacing() {
        // iPhone Duo outer display: 678 pt tall, about 526 pt above the pinned bar.
        #expect(OnboardingLayout.topSpacing(availableHeight: 526) == OnboardingLayout.compactTopSpacing)
        #expect(OnboardingLayout.topSpacing(availableHeight: 0) == OnboardingLayout.compactTopSpacing)
    }
}
