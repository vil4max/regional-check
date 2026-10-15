import StoreKit
import SwiftUI

/// The compact Pro sheet (ADR 0016): what the one-time purchase changes, Buy and Restore, and for
/// an owner the Pro icon switch. Text scales with Dynamic Type and the content scrolls.
struct ProSheetView: View {
    @Bindable var viewModel: ProSheetViewModel
    @State private var showsManageSubscriptions = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header
                itemsCard
                actions
                if let messageKey = viewModel.messageKey {
                    Text(LocalizedStringKey(messageKey))
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Text("pro.sheet.free_note")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.RedesignSpacing.screenInset)
            .padding(.vertical, Theme.Spacing.xl)
        }
        .background(Theme.RedesignColors.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await viewModel.load() }
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.title)
                .foregroundStyle(Theme.RedesignColors.proAccent)
                .accessibilityHidden(true)
            Text("Drive Check Pro")
                .font(Theme.RedesignTypography.regionName)
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            itemRow("pro.sheet.item.icon", systemImage: "app.badge")
            itemRow("pro.sheet.item.crown", systemImage: "crown")
            itemRow("pro.sheet.item.accent", systemImage: "paintpalette")
            if viewModel.phase == .owned {
                Divider().overlay(Theme.RedesignColors.separator)
                Toggle("pro.sheet.icon_toggle", isOn: $viewModel.usesProIcon)
                    .font(Theme.RedesignTypography.body)
                    .tint(Theme.RedesignColors.proAccent)
            }
        }
        .padding(Theme.RedesignCardSizes.paddingHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .fill(Theme.RedesignColors.surface)
        )
    }

    private func itemRow(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(Theme.RedesignTypography.body)
            .foregroundStyle(Theme.RedesignColors.textPrimary)
    }

    @ViewBuilder
    private var actions: some View {
        switch viewModel.phase {
        case .owned:
            Text("pro.sheet.owned")
                .font(Theme.RedesignTypography.body)
                .foregroundStyle(Theme.RedesignColors.proAccent)
                .multilineTextAlignment(.center)
            if viewModel.canManageSubscription {
                Button("subscription.paywall.manage") { showsManageSubscriptions = true }
                    .buttonStyle(.bordered)
            }
        case let .offer(price):
            Button {
                Task { await viewModel.buy() }
            } label: {
                Text("pro.sheet.buy \(price)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.RedesignColors.proAccent)
            .foregroundStyle(Theme.RedesignColors.background)
            .disabled(viewModel.isWorking)
            restoreButton
        case .loading:
            ProgressView()
            restoreButton
        case .unavailable:
            Text("pro.sheet.unavailable")
                .font(Theme.RedesignTypography.body)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
            restoreButton
        }
    }

    private var restoreButton: some View {
        Button("subscription.paywall.restore") {
            Task { await viewModel.restore() }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Theme.RedesignColors.textSecondary)
        .disabled(viewModel.isWorking)
    }
}
