import SwiftUI
import UIKit

struct MainTabView: View {
    enum Tab: Hashable {
        case status
        case regions
    }

    @Environment(AppContainer.self) private var container

    /// RD-16: gates the real first-launch `OnboardingView` cover (previously unused in
    /// production — see that view's header comment).
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: Tab
    @State private var showsAbout = false
    @State private var showsPaywall = false

    init(initialTab: Tab = .status) {
        _selectedTab = State(initialValue: initialTab)
    }

    private var controller: StatusController {
        container.status
    }

    private var location: any CarPlayLocationSource {
        container.location
    }

    private var regions: RegionSelection {
        container.regions
    }

    private var subscription: SubscriptionManager {
        container.subscription
    }

    /// RD-16: the real first-launch cover (Q1, "Onboarding → Get Started → Home"). Suppressed
    /// during DEBUG screenshot capture, which drives `OnboardingView` directly as its own root
    /// for the "onboarding" phase and would otherwise see it pop up unwanted over every other
    /// phase's fresh-install state (`AppLaunchArguments.screenshotPhase`).
    private var isFirstLaunchOnboardingPresented: Binding<Bool> {
        Binding(
            get: {
                #if DEBUG
                    if AppLaunchArguments.screenshotPhase != nil {
                        return false
                    }
                #endif
                return !hasCompletedOnboarding
            },
            set: { isPresented in
                if !isPresented {
                    hasCompletedOnboarding = true
                }
            }
        )
    }

    /// REQ-REGION-008: driven by `RegionSelection.shouldShowOutsideUkraineSheet`, not a "seen
    /// once ever" flag — see that type's header comment. Same screenshot-phase suppression as
    /// onboarding, for the same reason.
    ///
    /// Gated on `hasCompletedOnboarding` (drivecheck-product ruling): a first launch that is
    /// also outside Ukraine would otherwise want the onboarding `fullScreenCover` and this
    /// `sheet` presented at once, an unspecified SwiftUI stacking rather than a real order.
    /// Onboarding wins — it explains the app before anything else does — and this sheet's own
    /// trigger stays live underneath, so it still shows right after "Get Started" if the
    /// location resolves as outside Ukraine before onboarding completes.
    private var isOutsideUkraineSheetPresented: Binding<Bool> {
        Binding(
            get: {
                #if DEBUG
                    if AppLaunchArguments.screenshotPhase != nil {
                        return false
                    }
                #endif
                return hasCompletedOnboarding && regions.shouldShowOutsideUkraineSheet
            },
            set: { isPresented in
                if !isPresented {
                    regions.acknowledgeOutsideUkraineSheet()
                }
            }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("tab.status", systemImage: "steeringwheel", value: Tab.status) {
                withRegionChangeNotice(
                    HomeView(
                        showsOnboarding: $showsAbout,
                        showsPaywall: $showsPaywall
                    )
                )
            }
            SwiftUI.Tab("tab.regions", systemImage: "list.bullet", value: Tab.regions) {
                withRegionChangeNotice(RegionsView(viewModel: container.regionsViewModel))
            }
        }
        // The redesign's own chrome colour, not the system accent: this app has no `AccentColor`
        // asset, so an untinted `TabView` renders the selected tab in system blue against a
        // warm dark palette. `.standard` is the free palette; `RedesignPalette.pro` exists but
        // nothing selects it while Pro is hidden, so reading it from the entitlement here would
        // be wiring with no effect.
        .tint(Theme.RedesignPalette.standard.tabSelectedLabel)
        .onAppear {
            #if DEBUG
                if AppLaunchArguments.showsPaywallOnLaunch {
                    showsPaywall = true
                }
            #endif
            container.mainTabViewModel.appear(isOnboardingFinished: hasCompletedOnboarding)
        }
        // Two places set the flag (the cover's binding and "Get Started"); observing it covers both.
        .onChange(of: hasCompletedOnboarding) { _, finished in
            if finished {
                container.mainTabViewModel.onboardingFinished()
            }
        }
        .onChange(of: regions.selectedRegion) { _, region in
            container.mainTabViewModel.regionChanged(region)
        }
        .onChange(of: location.coordinateStamp) { _, _ in
            container.mainTabViewModel.locationChanged()
        }
        .onChange(of: controller.state.phase) { _, _ in
            container.mainTabViewModel.liveActivityContentChanged()
        }
        .onChange(of: subscription.isPro) { _, _ in
            container.mainTabViewModel.liveActivityContentChanged()
        }
        .onDisappear {
            container.mainTabViewModel.disappear()
        }
        .fullScreenCover(isPresented: isFirstLaunchOnboardingPresented) {
            OnboardingView(onContinue: {
                hasCompletedOnboarding = true
            })
        }
        .fullScreenCover(isPresented: $showsAbout) {
            AboutView(
                isPro: subscription.isPro,
                isLiveActivityEnabled: subscription.state.isLiveActivityEnabled,
                onToggleLiveActivity: { enabled in
                    container.mainTabViewModel.setLiveActivityEnabled(enabled)
                },
                onDismiss: {
                    AlternateIconManager.sync(isPro: subscription.isPro)
                    showsAbout = false
                }
            )
        }
        .sheet(isPresented: $showsPaywall) {
            PaywallView(
                manager: subscription,
                syncLiveActivity: container.syncLiveActivityContent,
                onDismiss: { showsPaywall = false }
            )
        }
        .sheet(isPresented: isOutsideUkraineSheetPresented) {
            OutsideUkraineInfoSheet(
                onDismiss: {
                    regions.acknowledgeOutsideUkraineSheet()
                },
                onChooseRegion: {
                    regions.acknowledgeOutsideUkraineSheet()
                    selectedTab = .regions
                }
            )
        }
    }

    /// REQ-REGION-007: the notice floats above the tab bar, never under or beside it. It is inset
    /// into each tab's content, not into the `TabView`: only inside a tab does the bottom safe
    /// area include the native tab bar, so an inset on the `TabView` itself lands beneath the bar,
    /// against the home indicator. Applied to both tabs so the notice and its Undo stay reachable
    /// whichever tab is showing when the tracker commits a new region.
    private func withRegionChangeNotice(_ content: some View) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if let notice = regions.regionChangeNotice {
                regionChangeNotice(notice)
                    .padding(.bottom, Theme.Spacing.sm)
            }
        }
    }

    private func regionChangeNotice(_ notice: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(notice)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.onFill)
                .lineLimit(2)
            Spacer(minLength: Theme.Spacing.sm)
            if regions.previousRegionForUndo != nil {
                Button("regions.changed_undo") {
                    regions.undoRegionChange()
                }
                .font(Theme.Typography.refreshLabel)
                .foregroundStyle(Theme.Colors.onboarding)
            }
            Button {
                regions.dismissRegionChangeNotice()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Theme.Colors.onFillSecondary)
            }
            .accessibilityLabel(Text("Close"))
        }
        .padding(Theme.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, Theme.Spacing.md)
    }
}

#if DEBUG
    #Preview("Main tabs") {
        // `@AppStorage("hasCompletedOnboarding")` reads `UserDefaults.standard` by default, which
        // `AppContainer.fixture()` does not isolate (unlike `SharedStore`/`EntitlementCache`,
        // which get their own wiped suite). Without `.defaultAppStorage` here, this preview's
        // first-launch state depends on whatever this simulator's real `UserDefaults.standard`
        // happens to hold, breaking `docs/engineering/testing-strategy.md`'s "snapshots never
        // touch ... shared persisted state" — so the onboarding cover would render unpredictably
        // instead of the settled tab content this snapshot is actually for.
        // `?? .standard` mirrors `AppContainerFixture.swift`'s fallback for the same call — the
        // named suite only fails to open in practice if the sandbox itself is broken.
        let previewDefaults = UserDefaults(suiteName: "vil4max.RegionalCheck.preview.mainTabView") ?? .standard
        previewDefaults.set(true, forKey: "hasCompletedOnboarding")
        return MainTabView()
            .environment(AppContainer.fixture())
            .defaultAppStorage(previewDefaults)
    }
#endif
