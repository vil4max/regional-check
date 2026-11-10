import DriveCheckKit
import StoreKit
import SwiftUI

/// The Details tab (ADR 0015, DETAILS-compact, UI-simplify): the settings a driver changes, as a
/// system inset-grouped list with Settings' own headers and footers and no row icons — the
/// location section when access is blocked, Alerts (Live Activities), Notifications and the iOS
/// notification settings under it, purchases, then About. One row is one setting, and each footer
/// says only what the driver gets from the setting above it (UI-simplify AC-11).
///
/// REQ-SURF-007: the Live Activities switch is shown to everyone, and About carries the Restore and
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
    /// The provider's own name, not translated.
    private static let sourceName = "Ubilling"

    private var sections: [DetailsSection] {
        DetailsLayout.sections(
            isLocationBlocked: viewModel.isLocationAccessBlocked,
            hasNotifications: viewModel.allClearPush != nil
        )
    }

    var body: some View {
        List {
            ForEach(sections, id: \.self) { sectionView($0) }
        }
        .listStyle(.insetGrouped)
        // `MainTabView` tints the tab bar's selection white, and the tint reaches its content
        // (`Color.accentColor` resolves to it too): the list takes the system blue back, and the
        // switches the system green.
        .tint(Color(uiColor: .systemBlue))
        .safeAreaBar(edge: .top, spacing: 0) {
            StatusToolbar(title: "tab.details")
        }
        // The permission watch, so the switch follows Settings after Open Settings and back
        // (REQ-SURF-008).
        .task {
            await viewModel.observeLiveActivityPermission()
        }
        .onChange(of: scenePhase) { _, phase in viewModel.sceneDidChange(isActive: phase == .active) }
        // Apple: `View.manageSubscriptionsSheet(isPresented:)`, StoreKit, iOS 15.0+
        // https://developer.apple.com/documentation/swiftui/view/managesubscriptionssheet(ispresented:)
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
    }

    @ViewBuilder
    private func sectionView(_ section: DetailsSection) -> some View {
        switch section {
        case .location: locationSection
        case .alerts: alertsSection
        case .notifications: notificationsSection
        case .notificationSettings: notificationSettingsSection
        case .purchases: purchasesSection
        case .about: aboutSection
        }
    }

    /// REQ-REGION-009: one row mirroring iOS's location access, in Apple's words, opening it; the
    /// footer says what turning it on gives.
    private var locationSection: some View {
        Section {
            Button(action: viewModel.openSettings) {
                DetailsValueRow(title: Text("details.location"), value: Text("details.location.never"))
            }
        } header: {
            Text("details.section.location")
                .textCase(.uppercase)
        } footer: {
            Text("location.access.enable_tip")
        }
    }

    /// UI-simplify AC-6: Apple's "Live Activities" switch; what it does is the footer. While iOS
    /// has Live Activities off, the footer says so and Open Settings is a row (REQ-SURF-008).
    private var alertsSection: some View {
        Section {
            Toggle(
                "details.liveActivities",
                isOn: Binding(
                    get: { viewModel.isLiveActivitySwitchOn },
                    set: { viewModel.setLiveActivityEnabled($0) }
                )
            )
            .tint(Color(uiColor: .systemGreen))
            .disabled(!viewModel.isLiveActivityAllowedBySystem)

            if !viewModel.isLiveActivityAllowedBySystem {
                Button("location.access.open_settings", action: viewModel.openSettings)
            }
        } header: {
            Text("details.section.alerts")
                .textCase(.uppercase)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("about.pro.liveActivity.caption")
                if !viewModel.isLiveActivityAllowedBySystem {
                    Text("details.liveActivity.systemOff")
                }
            }
        }
    }

    /// UI-simplify AC-7: the app's own switch, with what it gives the driver as the footer.
    @ViewBuilder
    private var notificationsSection: some View {
        if let push = viewModel.allClearPush {
            Section {
                AllClearPushSwitch(push: push)
            } header: {
                Text("details.section.notifications")
                    .textCase(.uppercase)
            } footer: {
                Text("details.allClear.caption")
            }
        }
    }

    /// UI-simplify AC-7, AC-11: the rows mirroring iOS's notification settings (ALERT-push), right
    /// under the switch they decide; each opens them.
    @ViewBuilder
    private var notificationSettingsSection: some View {
        if let push = viewModel.allClearPush {
            Section {
                NotificationSettingsRows(push: push, openSettings: viewModel.openNotificationSettings)
            }
        }
    }
}

extension DetailsView {
    private var purchaseRows: [DetailsPurchaseRow] {
        DetailsLayout.purchaseRows(
            showsPro: onOpenPro != nil, canManageSubscription: purchaseSettings.canManageSubscription)
    }

    /// UI-simplify AC-8: Pro, Restore Purchases and Manage Subscription, with no footer.
    private var purchasesSection: some View {
        Section {
            ForEach(purchaseRows, id: \.self) { purchaseRow($0) }
        }
    }

    /// UI-simplify AC-8, AC-11: information, not settings — the data source and the version; the
    /// disclaimer (REQ-PROVIDER-003) is the footer.
    private var aboutSection: some View {
        Section {
            ForEach(DetailsAboutRow.allCases, id: \.self) { aboutRow($0) }
        } header: {
            Text("details.section.about")
                .textCase(.uppercase)
        } footer: {
            Text("about.disclaimer")
        }
    }

    @ViewBuilder
    private func aboutRow(_ row: DetailsAboutRow) -> some View {
        switch row {
        case .dataSource:
            if let url = Self.sourceLinkURL {
                Link(destination: url) {
                    DetailsValueRow(title: Text("details.dataSource"), value: Text(verbatim: Self.sourceName))
                }
            }
        case .version:
            LabeledContent {
                Text(verbatim: viewModel.versionValue)
            } label: {
                Text("details.version")
            }
        }
    }

    @ViewBuilder
    private func purchaseRow(_ row: DetailsPurchaseRow) -> some View {
        switch row {
        case .pro:
            if let onOpenPro {
                Button(action: onOpenPro) {
                    DetailsValueRow(title: Text("Drive Check Pro"))
                }
            }
        case .restorePurchases:
            restoreRow
        case .manageSubscription:
            Button("subscription.paywall.manage") {
                showsManageSubscriptions = true
            }
        }
    }

    /// A tinted button row, as Settings draws an action; the outcome shows under it.
    private var restoreRow: some View {
        Button {
            Task { await purchaseSettings.restore() }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("subscription.paywall.restore")
                    Spacer(minLength: 0)
                    if purchaseSettings.isRestoring {
                        ProgressView()
                    }
                }
                if let messageKey = purchaseSettings.restoreMessageKey {
                    Text(LocalizedStringKey(messageKey))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(purchaseSettings.isRestoring)
    }
}

/// A Settings row that leads somewhere: the title, an optional value and a chevron, in the
/// system label colours rather than the button tint. Concrete `UIColor` labels, not `.primary`:
/// the hierarchical styles resolve against a `Button` or `Link` row's tint.
struct DetailsValueRow: View {
    let title: Text
    var value: Text?

    var body: some View {
        HStack(spacing: 8) {
            title
                .foregroundStyle(Color(uiColor: .label))
            Spacer(minLength: 8)
            if let value {
                value
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
