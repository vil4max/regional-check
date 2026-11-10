import DriveCheckKit
import StoreKit
import SwiftUI

/// The Details tab (ADR 0015, DETAILS-compact): the settings a driver changes, in few blocks — the
/// location row when access is blocked, Alerts (Live Activity and notifications), then About. The
/// country summary left Details on 2026-11-10; Status carries the region and its nearby line.
///
/// REQ-SURF-007: the Live Activity switch is shown to everyone, and About carries the Restore and
/// Manage Subscription routes the hidden paywall used to own.
struct DetailsView: View {
    var viewModel: DetailsViewModel
    var onOpenPro: (() -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @State private var purchaseSettings: PurchaseSettingsViewModel
    @State private var showsManageSubscriptions = false

    init(
        viewModel: DetailsViewModel,
        purchases: any PurchaseRestoring,
        onOpenPro: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onOpenPro = onOpenPro
        _purchaseSettings = State(initialValue: PurchaseSettingsViewModel(purchases: purchases))
    }

    private static let sourceLinkURL = URL(string: "https://wiki.ubilling.net.ua/doku.php?id=aerialalertsapi")

    var body: some View {
        ZStack {
            Theme.RedesignColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    ForEach(DetailsLayout.sections(isLocationBlocked: viewModel.isLocationAccessBlocked), id: \.self) {
                        sectionView($0)
                    }
                }
                .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                .padding(.top, Theme.RedesignSpacing.toolbarGap)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .safeAreaBar(edge: .top, spacing: 0) {
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
                openSettingsButton
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: DetailsSection) -> some View {
        switch section {
        case .location: locationSection
        case .alerts: alertsSection
        case .about: aboutSection
        }
    }

    /// Live Activity and notifications in one block, each with a one-line caption. The permission
    /// watch lives here, so the switch follows Settings after Open Settings and back (REQ-SURF-008).
    private var alertsSection: some View {
        section("details.section.alerts") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(
                    isOn: Binding(
                        get: { viewModel.isLiveActivitySwitchOn },
                        set: { viewModel.setLiveActivityEnabled($0) }
                    )
                ) {
                    HStack(spacing: Theme.RedesignCardSizes.innerGap) {
                        rowIcon("iphone")
                        Text("subscription.liveActivity.toggle")
                            .font(Theme.RedesignTypography.body)
                            .foregroundStyle(Theme.RedesignColors.textPrimary)
                    }
                }
                .tint(Theme.RedesignColors.statusClear)
                .disabled(!viewModel.isLiveActivityAllowedBySystem)

                Text("about.pro.liveActivity.caption")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                    .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)

                if !viewModel.isLiveActivityAllowedBySystem {
                    liveActivitySystemOffNote
                }
            }
            .padding(.vertical, Theme.RedesignCardSizes.innerGap)

            // REQ-PUSH-001: the notification switch, when the app built one.
            if let push = viewModel.allClearPush {
                Divider().overlay(Theme.RedesignColors.separator)
                AllClearPushSwitch(push: push, openSettings: viewModel.openNotificationSettings)
            }
        }
        .task {
            await viewModel.observeLiveActivityPermission()
        }
        .onChange(of: scenePhase) { _, phase in viewModel.sceneDidChange(isActive: phase == .active) }
    }

    /// REQ-SURF-008: why the switch is off and where to change it.
    private var liveActivitySystemOffNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.RedesignCardSizes.innerGap) {
            Text("details.liveActivity.systemOff")
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.statusStale)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            openSettingsButton
        }
        .padding(.leading, 22 + Theme.RedesignCardSizes.innerGap)
        .padding(.top, Theme.Spacing.sm)
    }

    private var openSettingsButton: some View {
        Button("location.access.open_settings", action: viewModel.openSettings)
            .font(Theme.RedesignTypography.caption.weight(.semibold))
            .foregroundStyle(Theme.RedesignColors.statusStale)
            .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
    }

    @ViewBuilder
    private var dataSourceRow: some View {
        if let url = Self.sourceLinkURL {
            Link(destination: url) {
                settingsRow(icon: "arrow.up.right", title: "about.source_link") {
                    EmptyView()
                }
            }
            .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
        }
    }

    private var disclaimerRow: some View {
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

    private var versionRow: some View {
        Text(viewModel.versionBuildText)
            .font(Theme.RedesignTypography.caption)
            .foregroundStyle(Theme.RedesignColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, Theme.Spacing.sm)
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Row building blocks

extension DetailsView {
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

extension DetailsView {
    private var aboutRows: [DetailsAboutRow] {
        DetailsLayout.aboutRows(
            showsPro: onOpenPro != nil, canManageSubscription: purchaseSettings.canManageSubscription)
    }

    /// Purchases, the data source and the version as one block (DETAILS-compact AC-5); the rows and
    /// their conditions follow `DetailsLayout.aboutRows`.
    private var aboutSection: some View {
        section("details.section.about") {
            ForEach(Array(aboutRows.enumerated()), id: \.element) { index, row in
                // No divider between the disclaimer and the version: they read as one footnote.
                if index > 0, row != .version {
                    Divider().overlay(Theme.RedesignColors.separator)
                }
                aboutRow(row)
            }
        }
    }

    @ViewBuilder
    private func aboutRow(_ row: DetailsAboutRow) -> some View {
        switch row {
        case .pro:
            if let onOpenPro {
                Button(action: onOpenPro) {
                    settingsRow(icon: "crown", title: "Drive Check Pro") { EmptyView() }
                }
                .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
            }
        case .restorePurchases:
            restoreRow
        case .manageSubscription:
            Button {
                showsManageSubscriptions = true
            } label: {
                settingsRow(icon: "creditcard", title: "subscription.paywall.manage") { EmptyView() }
            }
            .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
        case .dataSource:
            dataSourceRow
        case .disclaimer:
            disclaimerRow
        case .version:
            versionRow
        }
    }

    @ViewBuilder
    private var restoreRow: some View {
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
    }
}

/// The container-backed Details tab, the counterpart of `HomeView` for Status.
struct DetailsTabView: View {
    @Environment(AppContainer.self) private var container
    @State private var proSheet: ProSheetViewModel?

    var body: some View {
        DetailsView(
            viewModel: container.detailsViewModel,
            purchases: container.subscription,
            onOpenPro: container.proAppearance.showsEntry ? { proSheet = container.makeProSheetViewModel() } : nil
        )
        .sheet(item: $proSheet) { ProSheetView(viewModel: $0) }
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

    #Preview("Details Live Activities off") {
        DetailsTabView()
            .environment(AppContainer.fixture(liveActivitiesAllowed: false))
    }

    #Preview("Details AX5") {
        DetailsTabView()
            .environment(AppContainer.fixture(region: .kharkiv))
            .dynamicTypeSize(.accessibility5)
    }
#endif
