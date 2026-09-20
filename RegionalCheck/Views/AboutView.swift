import StoreKit
import SwiftUI

/// RD-16: the About screen (`docs/design/redesign/screens-onboarding-about-paywall.md` §2). Full-
/// screen cover from the round About button (currently `StatusToolbar.onShowInfo`, RD-5's owned
/// file — this view only owns what is presented, not the trigger). Split out of `OnboardingView`,
/// which used to double as About via a `purpose` flag; the two have unrelated layouts now.
///
/// REQ-SURF-007: no Pro chip, the Live Activity switch is shown to everyone, and the Purchases
/// section carries the Restore and Manage Subscription routes the hidden paywall used to own.
struct AboutView: View {
    var isLiveActivityEnabled: Bool
    var onToggleLiveActivity: ((Bool) -> Void)?
    var onDismiss: () -> Void

    @State private var purchaseSettings: PurchaseSettingsViewModel
    @State private var showsManageSubscriptions = false

    init(
        isLiveActivityEnabled: Bool,
        purchases: any PurchaseRestoring,
        onToggleLiveActivity: ((Bool) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.isLiveActivityEnabled = isLiveActivityEnabled
        self.onToggleLiveActivity = onToggleLiveActivity
        self.onDismiss = onDismiss
        _purchaseSettings = State(initialValue: PurchaseSettingsViewModel(purchases: purchases))
    }

    private static let sourceLinkURL = URL(string: "https://wiki.ubilling.net.ua/doku.php?id=aerialalertsapi")!

    var body: some View {
        ZStack {
            Theme.RedesignColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("About")
                    .font(Theme.RedesignTypography.navTitle)
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                    .padding(.top, Theme.RedesignSpacing.contentTop - 20)

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        header

                        liveActivitySection
                        purchasesSection
                        dataSection
                    }
                    .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
                }

                bottomBar
            }
        }
        // Apple: `View.manageSubscriptionsSheet(isPresented:)`, StoreKit, iOS 15.0+
        // https://developer.apple.com/documentation/swiftui/view/managesubscriptionssheet(ispresented:)
        .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "steeringwheel")
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .frame(width: 96, height: 96)
                .background(Color.white.opacity(0.06), in: Circle())
                .accessibilityHidden(true)

            Text("Drive Check")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var liveActivitySection: some View {
        VStack(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap) {
            sectionHeader(String(localized: "about.section.liveActivity"))

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: Binding(
                    get: { isLiveActivityEnabled },
                    set: { onToggleLiveActivity?($0) }
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
                    .padding(.leading, Theme.RedesignRowSizes.grouped)
            }
            .padding(Theme.RedesignCardSizes.paddingHorizontal)
            .background(
                RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                    .fill(Theme.RedesignColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                    .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purchasesSection: some View {
        VStack(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap) {
            sectionHeader(String(localized: "about.section.purchases"))

            VStack(spacing: 0) {
                Button {
                    Task { await purchaseSettings.restore() }
                } label: {
                    purchaseRow(icon: "arrow.clockwise", title: "subscription.paywall.restore") {
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
                        purchaseRow(icon: "creditcard", title: "subscription.paywall.manage") {
                            EmptyView()
                        }
                    }
                    .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
                }
            }
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
            .background(
                RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                    .fill(Theme.RedesignColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                    .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func purchaseRow(
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

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap) {
            sectionHeader("DATA")

            VStack(spacing: 0) {
                Link(destination: Self.sourceLinkURL) {
                    HStack(spacing: Theme.RedesignCardSizes.innerGap) {
                        rowIcon("arrow.up.right")
                        Text("about.source_link")
                            .font(Theme.RedesignTypography.body)
                            .foregroundStyle(Theme.RedesignColors.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: Theme.RedesignRowSizes.grouped)
                }

                Divider().overlay(Theme.RedesignColors.separator)

                HStack(alignment: .top, spacing: Theme.RedesignCardSizes.innerGap) {
                    rowIcon("info.circle")
                    Text("about.disclaimer")
                        .font(.system(size: 14, design: .rounded))
                        .lineSpacing(5)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
            .background(
                RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                    .fill(Theme.RedesignColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                    .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.RedesignTypography.sectionHeader)
            .tracking(Theme.RedesignTypography.sectionHeaderTracking)
            .foregroundStyle(Theme.RedesignColors.textTertiary)
    }

    private func rowIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.RedesignColors.textTertiary)
            .frame(width: 22, alignment: .center)
            .accessibilityHidden(true)
    }

    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button(action: onDismiss) {
                Text("Got It")
                    .font(Theme.RedesignTypography.navTitle)
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
            .redesignGlassSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .accessibilityLabel(Text("Got It"))

            Text(versionBuildText)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .accessibilityAddTraits(.isStaticText)
        }
        .padding(.horizontal, Theme.RedesignSpacing.screenInset)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var versionBuildText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return String(format: String(localized: "about.version_build %@ %@"), version, build)
    }
}

#if DEBUG
    #Preview("About") {
        AboutView(
            isLiveActivityEnabled: true,
            purchases: AppContainer.fixture().subscription,
            onDismiss: {}
        )
    }

    // An active entitlement is the only thing that adds the Manage Subscription row.
    #Preview("About subscribed") {
        AboutView(
            isLiveActivityEnabled: true,
            purchases: AppContainer.fixture(isPro: true).subscription,
            onDismiss: {}
        )
    }
#endif
