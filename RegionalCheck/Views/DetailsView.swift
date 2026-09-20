import DriveCheckKit
import StoreKit
import SwiftUI
import UIKit

/// The Details tab (ADR 0015): the full summary, then the app's settings. It absorbed the About
/// screen, whose chrome — a title of its own, "Got It", a full-screen cover to dismiss — has no
/// role inside a tab.
///
/// REQ-SURF-007: the Live Activity switch is shown to everyone, and the Purchases section carries
/// the Restore and Manage Subscription routes the hidden paywall used to own.
struct DetailsView: View {
    var controller: StatusController
    var sourceLabel: String?
    var statusDetailsViewModel: StatusDetailsViewModel?
    var viewModel: DetailsViewModel
    var onOpenLocationSettings: (() -> Void)?

    @State private var purchaseSettings: PurchaseSettingsViewModel
    @State private var showsManageSubscriptions = false

    init(
        controller: StatusController,
        sourceLabel: String?,
        statusDetailsViewModel: StatusDetailsViewModel?,
        viewModel: DetailsViewModel,
        purchases: any PurchaseRestoring,
        onOpenLocationSettings: (() -> Void)? = nil
    ) {
        self.controller = controller
        self.sourceLabel = sourceLabel
        self.statusDetailsViewModel = statusDetailsViewModel
        self.viewModel = viewModel
        self.onOpenLocationSettings = onOpenLocationSettings
        _purchaseSettings = State(initialValue: PurchaseSettingsViewModel(purchases: purchases))
    }

    private static let sourceLinkURL = URL(string: "https://wiki.ubilling.net.ua/doku.php?id=aerialalertsapi")

    private var accent: Theme.RedesignStatusAccent {
        Theme.RedesignStatusAccent(phase: controller.state.phase, isStale: controller.isDataStale)
    }

    var body: some View {
        ZStack {
            Theme.RedesignColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    StatusSummaryCard(
                        sourceLabel: sourceLabel,
                        statusDetailsViewModel: statusDetailsViewModel,
                        snapshot: controller.lastSnapshot,
                        accent: accent
                    )

                    if viewModel.isLocationAccessBlocked {
                        locationSection
                    }
                    liveActivitySection
                    purchasesSection
                    dataSection

                    Text(viewModel.versionBuildText)
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                        .accessibilityAddTraits(.isStaticText)
                }
                .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                .padding(.top, Theme.RedesignSpacing.toolbarFade)
                .padding(.bottom, Theme.Spacing.xl)
                .statusDetailsLifecycle(statusDetailsViewModel)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                StatusToolbar(title: "tab.details")
            }
        }
        // Apple: `View.manageSubscriptionsSheet(isPresented:)`, StoreKit, iOS 15.0+
        // https://developer.apple.com/documentation/swiftui/view/managesubscriptionssheet(ispresented:)
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
    }

    private var locationSection: some View {
        section("details.section.location") {
            settingsRow(icon: "location.slash", title: "location.access.denied") {
                if let onOpenLocationSettings {
                    Button("location.access.open_settings", action: onOpenLocationSettings)
                        .font(Theme.RedesignTypography.caption.weight(.semibold))
                        .foregroundStyle(Theme.RedesignColors.statusStale)
                }
            }
        }
    }

    private var liveActivitySection: some View {
        section("about.section.liveActivity") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: Binding(
                    get: { viewModel.isLiveActivityEnabled },
                    set: { viewModel.setLiveActivityEnabled($0) }
                )) {
                    HStack(spacing: Theme.RedesignCardSizes.innerGap) {
                        rowIcon("iphone")
                        Text("subscription.liveActivity.toggle")
                            .font(Theme.RedesignTypography.body)
                            .foregroundStyle(Theme.RedesignColors.textPrimary)
                    }
                }
                .tint(Theme.RedesignColors.statusClear)

                Text("about.pro.liveActivity.caption")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)
            }
            .padding(.vertical, Theme.RedesignCardSizes.innerGap)
        }
    }

    private var purchasesSection: some View {
        section("about.section.purchases") {
            Button {
                Task { await purchaseSettings.restore() }
            } label: {
                settingsRow(icon: "arrow.clockwise", title: "subscription.paywall.restore") {
                    if purchaseSettings.isRestoring {
                        ProgressView()
                            .tint(Theme.RedesignColors.textSecondary)
                    }
                }
            }
            .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
            .disabled(purchaseSettings.isRestoring)

            if let messageKey = purchaseSettings.restoreMessageKey {
                Text(LocalizedStringKey(messageKey))
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)
                    .padding(.bottom, Theme.Spacing.sm)
                    .accessibilityAddTraits(.isStaticText)
            }

            if purchaseSettings.canManageSubscription {
                Divider().overlay(Theme.RedesignColors.separator)

                Button {
                    showsManageSubscriptions = true
                } label: {
                    settingsRow(icon: "creditcard", title: "subscription.paywall.manage") {
                        EmptyView()
                    }
                }
                .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
            }
        }
    }

    private var dataSection: some View {
        section("about.section.data") {
            if let url = Self.sourceLinkURL {
                Link(destination: url) {
                    settingsRow(icon: "arrow.up.right", title: "about.source_link") {
                        EmptyView()
                    }
                }

                Divider().overlay(Theme.RedesignColors.separator)
            }

            HStack(alignment: .top, spacing: Theme.RedesignCardSizes.innerGap) {
                rowIcon("info.circle")
                Text("about.disclaimer")
                    .font(Theme.RedesignTypography.caption)
                    .lineSpacing(5)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private func section(
        _ title: LocalizedStringKey,
        @ViewBuilder rows: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap) {
            Text(title)
                .font(Theme.RedesignTypography.sectionHeader)
                .tracking(Theme.RedesignTypography.sectionHeaderTracking)
                .foregroundStyle(Theme.RedesignColors.textTertiary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0, content: rows)
                .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
                .background(
                    Theme.RedesignColors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                        .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow(
        icon: String,
        title: LocalizedStringKey,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: Theme.RedesignCardSizes.innerGap) {
            rowIcon(icon)
            Text(title)
                .font(Theme.RedesignTypography.body)
                .foregroundStyle(Theme.RedesignColors.textPrimary)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(minHeight: Theme.RedesignRowSizes.grouped)
        .contentShape(Rectangle())
    }

    private func rowIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.RedesignColors.textTertiary)
            .frame(width: 22, alignment: .center)
            .accessibilityHidden(true)
    }
}

/// The container-backed Details tab, the counterpart of `HomeView` for Status.
struct DetailsTabView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        DetailsView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            viewModel: container.detailsViewModel,
            purchases: container.subscription,
            onOpenLocationSettings: {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        )
    }
}

#if DEBUG
    #Preview("Details") {
        DetailsTabView()
            .environment(AppContainer.fixture(region: .kharkiv))
    }

    // An active entitlement is the only thing that adds the Manage Subscription row.
    #Preview("Details subscribed") {
        DetailsTabView()
            .environment(AppContainer.fixture(isPro: true))
    }

    #Preview("Details location denied") {
        DetailsTabView()
            .environment(AppContainer.fixture(locationAuthorization: .denied))
    }

    #Preview("Details AX5") {
        DetailsTabView()
            .environment(AppContainer.fixture(region: .kharkiv))
            .dynamicTypeSize(.accessibility5)
    }
#endif
