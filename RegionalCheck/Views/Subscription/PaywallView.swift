import StoreKit
import SwiftUI

struct PaywallView: View {
    @State private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsManageSubscriptions = false

    private let privacyURL = URL(string: "https://vil4max.github.io/regional-check/privacy-policy.html")!
    private let termsURL = URL(string: "https://vil4max.github.io/regional-check/terms-of-use.html")!

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
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header
                    benefitsCard
                    #if DEBUG
                        storeStatusCard
                    #endif
                    plansSection
                    if let message = viewModel.statusMessage {
                        Text(message)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.onFillSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.Colors.dashboard.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.Colors.onFillSecondary)
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
            .task {
                await viewModel.onAppear()
            }
            .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
        }
    }
}

private extension PaywallView {
    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.Colors.onboarding)
                .accessibilityHidden(true)

            Text("Drive Check Pro")
                .font(Theme.Typography.regionTitle)
                .foregroundStyle(Theme.Colors.onFill)
                .multilineTextAlignment(.center)

            Text("subscription.paywall.subtitle")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.onFillSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            benefitRow("subscription.benefit.liveActivity")
            benefitRow("subscription.benefit.badge")
            benefitRow("subscription.benefit.detail")
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Colors.separator, lineWidth: 1)
        )
    }

    private var storeStatusCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("subscription.status.title")
                .font(Theme.Typography.refreshLabel)
                .foregroundStyle(Theme.Colors.onFillSecondary)

            statusLine(viewModel.accessStatusLine)
            statusLine(viewModel.entitlementStatusLine)
            statusLine(viewModel.runtimeLine)
            statusLine(viewModel.storeKitStatusLine)
            statusLine(viewModel.expectedProductIDsLine)
            statusLine(viewModel.catalogSourceLine)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Colors.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("subscription.paywall.plans")
                .font(Theme.Typography.refreshLabel)
                .foregroundStyle(Theme.Colors.onFillSecondary)

            switch viewModel.plansContent {
            case .loading:
                ProgressView()
                    .tint(Theme.Colors.onFill)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .accessibilityLabel(Text("subscription.paywall.loading"))
            case .empty:
                VStack(spacing: Theme.Spacing.md) {
                    if let errorMessage = viewModel.loadErrorMessage {
                        Text(errorMessage)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.onFillSecondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("subscription.paywall.empty")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.onFillSecondary)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        Task { await viewModel.reloadProducts() }
                    } label: {
                        Text("subscription.paywall.retry")
                            .font(Theme.Typography.refreshLabel)
                            .foregroundStyle(Theme.Colors.onFill)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm + 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Theme.Colors.separator, lineWidth: 1)
                            )
                    }
                    .buttonStyle(HapticButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
            case let .ready(products):
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(products) { product in
                        productRow(product)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.md) {
            if viewModel.selectedProduct != nil {
                Button {
                    Task { await viewModel.purchase() }
                } label: {
                    Group {
                        if viewModel.isBusy {
                            ProgressView()
                                .tint(Theme.Colors.dashboard)
                        } else {
                            Text(viewModel.subscribeTitle)
                                .font(Theme.Typography.refreshLabel)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .foregroundStyle(Theme.Colors.dashboard)
                    .background(Theme.Colors.onboarding, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(viewModel.isBusy)
            }

            HStack(spacing: Theme.Spacing.lg) {
                Button {
                    Task { await viewModel.restore() }
                } label: {
                    Text("subscription.paywall.restore")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                }
                .buttonStyle(HapticButtonStyle())
                .disabled(viewModel.isBusy)

                Button {
                    showsManageSubscriptions = true
                } label: {
                    Text("subscription.paywall.manage")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                }
                .buttonStyle(HapticButtonStyle())
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: Theme.Spacing.sm) {
                Text("subscription.paywall.autoRenew")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Theme.Spacing.md) {
                    Link("subscription.paywall.privacy", destination: privacyURL)
                    Text("·")
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                        .accessibilityHidden(true)
                    Link("subscription.paywall.terms", destination: termsURL)
                }
                .font(Theme.Typography.caption)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
        .background(
            Theme.Colors.dashboard
                .shadow(color: Theme.Shadows.soft, radius: Theme.Shadows.softRadius, y: -Theme.Shadows.softY)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func benefitRow(_ key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(Theme.Colors.normal)
                .accessibilityHidden(true)
            Text(key)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.onFill)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func statusLine(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.onFill)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func productRow(_ product: SubscriptionProduct) -> some View {
        let selected = viewModel.selectedProductID == product.id
        return Button {
            viewModel.selectedProductID = product.id
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.Colors.normal : Theme.Colors.onFillSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(Theme.Typography.refreshLabel)
                        .foregroundStyle(Theme.Colors.onFill)
                    Text(product.periodDescription)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Text(product.displayPrice)
                    .font(Theme.Typography.refreshLabel)
                    .foregroundStyle(Theme.Colors.onFill)
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Theme.Colors.normal.opacity(0.14) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.Colors.normal : Theme.Colors.separator,
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }
}
