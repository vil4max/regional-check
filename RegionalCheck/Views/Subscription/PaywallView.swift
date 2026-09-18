import StoreKit
import SwiftUI

/// RD-16: `docs/design/redesign/screens-onboarding-about-paywall.md` §3. Five states —
/// loading / plans / error / empty / subscribed — driven by `PaywallViewModel.contentState`.
struct PaywallView: View {
    // Not `private`: `PaywallView+PlansSection.swift` (a same-type extension in a separate
    // file, split out to stay under the file-length lint limit) reads it too.
    @State var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsManageSubscriptions = false

    private enum PaywallLinks {
        static let privacy = URL(string: "https://vil4max.github.io/regional-check/privacy-policy.html")
        static let terms = URL(string: "https://vil4max.github.io/regional-check/terms-of-use.html")
    }

    init(
        manager: any SubscriptionManaging,
        syncLiveActivity: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: PaywallViewModel(
                manager: manager,
                syncLiveActivity: syncLiveActivity,
                onDismiss: onDismiss
            )
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.RedesignColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header
                    benefitsCard
                    plansSection
                    if let message = viewModel.statusMessage {
                        Text(message)
                            .font(Theme.RedesignTypography.caption)
                            .foregroundStyle(Theme.RedesignColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
                .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                .padding(.top, 56)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
            }

            closeButton
        }
        .presentationDetents([.large])
        .presentationCornerRadius(34)
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.onAppear()
        }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
    }
}

private extension PaywallView {
    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .frame(
                    width: Theme.RedesignControlSizes.navButton,
                    height: Theme.RedesignControlSizes.navButton
                )
        }
        .redesignGlassSurface(in: Circle())
        .padding(.trailing, Theme.RedesignSpacing.screenInset)
        .padding(.top, Theme.Spacing.md)
        .accessibilityLabel(Text("Close"))
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.RedesignColors.proAccent)
                .frame(width: 56, height: 56)
                .background(
                    Theme.RedesignColors.proAccent.opacity(0.14),
                    in: Circle()
                )
                .overlay(
                    Circle().strokeBorder(Theme.RedesignColors.proAccent.opacity(0.40), lineWidth: 1)
                )
                .accessibilityHidden(true)

            Text("Drive Check Pro")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("subscription.paywall.subtitle")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // P2 / the Never list: the paywall never implies the alert signal is paid.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield")
                    .accessibilityHidden(true)
                Text("subscription.paywall.staysFree")
            }
            .font(Theme.RedesignTypography.caption)
            .foregroundStyle(Theme.RedesignColors.textPrimary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            benefitRow("subscription.benefit.liveActivity", systemImage: "iphone")
            benefitRow("subscription.benefit.badge", systemImage: "seal")
            benefitRow("subscription.benefit.detail", systemImage: "text.bubble")
        }
        .padding(Theme.RedesignCardSizes.paddingHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .fill(Theme.RedesignColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.md) {
            switch viewModel.contentState {
            case .subscribed:
                // Behavior change #1: Manage Subscription is the primary action for a
                // subscriber, and only a subscriber ever sees it (never shown below to a
                // non-subscriber's Restore/Privacy/Terms row).
                Button {
                    showsManageSubscriptions = true
                } label: {
                    Text("subscription.paywall.manage")
                        .font(Theme.RedesignTypography.body.weight(.semibold))
                        .foregroundStyle(Theme.RedesignColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(HapticButtonStyle())
                .redesignGlassSurface(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            case let .plans(products) where !products.isEmpty:
                subscribeButton
            case .loading, .error, .empty, .plans:
                EmptyView()
            }

            if viewModel.contentState != .subscribed {
                linksRow
            }
        }
        .padding(.horizontal, Theme.RedesignSpacing.screenInset)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .background(
            Theme.RedesignColors.background
                .shadow(color: Theme.Shadows.soft, radius: Theme.Shadows.softRadius, y: -Theme.Shadows.softY)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var subscribeButton: some View {
        Button {
            Task { await viewModel.purchase() }
        } label: {
            Group {
                if viewModel.isBusy {
                    ProgressView()
                        .tint(Theme.RedesignColors.textOnStale)
                } else {
                    Text(viewModel.subscribeTitle)
                        .font(Theme.RedesignTypography.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(Theme.RedesignColors.textOnStale)
            .background(Theme.RedesignColors.proAccent, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(HapticButtonStyle())
        .disabled(viewModel.isBusy)
    }

    private var linksRow: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.lg) {
                Button {
                    Task { await viewModel.restore() }
                } label: {
                    Text("subscription.paywall.restore")
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(viewModel.isBusy)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: Theme.Spacing.sm) {
                Text("subscription.paywall.autoRenew")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Theme.Spacing.md) {
                    if let privacy = PaywallLinks.privacy {
                        Link("subscription.paywall.privacy", destination: privacy)
                    }
                    if PaywallLinks.privacy != nil, PaywallLinks.terms != nil {
                        Text("·")
                            .foregroundStyle(Theme.RedesignColors.textSecondary)
                            .accessibilityHidden(true)
                    }
                    if let terms = PaywallLinks.terms {
                        Link("subscription.paywall.terms", destination: terms)
                    }
                }
                .font(Theme.RedesignTypography.caption)
                .tint(Theme.RedesignColors.textSecondary)
            }
        }
    }

    private func benefitRow(_ key: LocalizedStringKey, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(Theme.RedesignColors.proAccent)
                .accessibilityHidden(true)
            Text(key)
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// Explicit `internal`, overriding this `private extension`'s default: called from
    /// `PaywallView+PlansSection.swift`.
    internal func productRow(_ product: SubscriptionProduct) -> some View {
        let selected = viewModel.selectedProductID == product.id
        return Button {
            viewModel.selectedProductID = product.id
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.RedesignColors.textOnStale : Theme.RedesignColors.textTertiary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(Theme.RedesignTypography.body.weight(.semibold))
                        .foregroundStyle(Theme.RedesignColors.textPrimary)
                    Text(product.periodDescription)
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Text(product.displayPrice)
                    .font(Theme.RedesignTypography.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
            }
            .frame(minHeight: 64)
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? Theme.RedesignColors.proAccent.opacity(0.10) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.RedesignColors.proAccent : Theme.RedesignColors.surfaceStroke,
                        lineWidth: selected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}

// Preview content (all `#Preview`s and the preview-only fixture manager) lives in
// `PaywallView+Previews.swift` — keeps this file under `Tooling/.swiftlint.yml`'s file-length
// limit without touching the view or view model.
