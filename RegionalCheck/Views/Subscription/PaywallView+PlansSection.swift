import SwiftUI

/// The plans area's per-state rendering (`PaywallViewModel.ContentState`) — split out of
/// `PaywallView.swift` to keep that file under `Tooling/.swiftlint.yml`'s file-length limit.
extension PaywallView {
    @ViewBuilder
    var plansSection: some View {
        switch viewModel.contentState {
        case .subscribed:
            subscribedCard
        case .loading:
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                plansHeader
                loadingSkeleton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case let .error(message):
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                plansHeader
                messageCard(
                    systemImage: "wifi.exclamationmark",
                    title: String(localized: "subscription.error.unavailable"),
                    body: message.isEmpty ? String(localized: "subscription.paywall.error.body") : message
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .empty:
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                plansHeader
                messageCard(
                    systemImage: "tray",
                    title: String(localized: "subscription.paywall.empty.title"),
                    body: String(localized: "subscription.paywall.empty.body")
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case let .plans(products):
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                plansHeader
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(products) { product in
                        productRow(product)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var plansHeader: some View {
        Text("subscription.paywall.plans")
            .font(Theme.RedesignTypography.sectionHeader)
            .tracking(Theme.RedesignTypography.sectionHeaderTracking)
            .foregroundStyle(Theme.RedesignColors.textSecondary)
            .textCase(.uppercase)
    }

    var loadingSkeleton: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                ProgressView()
                    .tint(Theme.RedesignColors.textPrimary)
                Text("subscription.paywall.loading")
                    .font(Theme.RedesignTypography.body)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                Spacer(minLength: 0)
            }
            .frame(height: 64)
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("subscription.paywall.loading"))

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .frame(height: 64)
                .accessibilityHidden(true)
        }
    }

    func messageCard(systemImage: String, title: String, body: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(Theme.RedesignTypography.body.weight(.semibold))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(body)
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.reloadProducts() }
            } label: {
                Text("subscription.paywall.retry")
                    .font(Theme.RedesignTypography.body.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.RedesignControlSizes.navButton)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(HapticButtonStyle())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.RedesignCardSizes.paddingHorizontal)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .fill(Theme.RedesignColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }

    var subscribedCard: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 28))
                .foregroundStyle(Theme.RedesignColors.proAccent)
                .accessibilityHidden(true)
            Text("subscription.paywall.subscribed.title")
                .font(Theme.RedesignTypography.body.weight(.semibold))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
            Text(viewModel.subscribedDetailLine)
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
            Text("subscription.paywall.subscribed.thanks")
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.RedesignCardSizes.paddingHorizontal)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .fill(Theme.RedesignColors.proAccent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.proAccent.opacity(0.30), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
