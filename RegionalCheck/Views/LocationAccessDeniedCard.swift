import SwiftUI

/// The Status tab's location-access-denied card (REQ-REGION-009): with location denied the region
/// rests on its fallback, and the card says so and offers the way to Settings. The host decides
/// whether to show it.
struct LocationAccessDeniedCard: View {
    let onOpenLocationSettings: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.RedesignCardSizes.innerGap) {
            Image(systemName: "location.slash")
                .foregroundStyle(Theme.RedesignColors.statusStale)

            VStack(alignment: .leading, spacing: 2) {
                Text("location.access.denied")
                    .font(Theme.RedesignTypography.body.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                Text("location.access.enable_tip")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
            }

            Spacer(minLength: Theme.RedesignCardSizes.innerGap)

            if let onOpenLocationSettings {
                Button("location.access.open_settings", action: onOpenLocationSettings)
                    .font(Theme.RedesignTypography.caption.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.statusStale)
            }
        }
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .padding(.vertical, Theme.RedesignCardSizes.innerGap)
        .accessibilityElement(children: .combine)
        .background(
            Theme.RedesignColors.surface,
            in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }
}
