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

    /// RD-4: the redesign chrome palette, following the live Pro entitlement (RD-2 §2). Injected
    /// here at the app root so any redesigned view below reads the same palette from the
    /// environment; `RedesignBottomBar` also receives it directly as it's built in this file.
    private var redesignPalette: Theme.RedesignPalette {
        Theme.RedesignPalette.current(isProEntitled: subscription.isPro)
    }

    private var bottomBarAction: RedesignBottomBar.Action {
        .forSelectedTab(selectedTab, isLoading: controller.isLoading, isDataStale: controller.isDataStale)
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
    private var isOutsideUkraineSheetPresented: Binding<Bool> {
        Binding(
            get: {
                #if DEBUG
                    if AppLaunchArguments.screenshotPhase != nil {
                        return false
                    }
                #endif
                return regions.shouldShowOutsideUkraineSheet
            },
            set: { isPresented in
                if !isPresented {
                    regions.acknowledgeOutsideUkraineSheet()
                }
            }
        )
    }

    var body: some View {
        // Not a `TabView`: on this iOS 27 build, no combination of `.toolbarVisibility`,
        // `.toolbarBackgroundVisibility`, `.tabBarMinimizeBehavior(.never)`, the deprecated
        // `.toolbar(.hidden, for:)`, or switching `.tag()` children to the `Tab(value:)` builder
        // fully suppressed the system tab bar's glass background — confirmed by temporarily
        // restoring `.tabItem`, which revealed a second, fully-labeled native bar underneath
        // `RedesignBottomBar` regardless of which hide API was active. A plain content switch has
        // no native tab bar to leak through. `RedesignBottomBar` drives `selectedTab` directly;
        // this trades the system's swipe-between-tabs gesture and built-in transition for a
        // correct, mockup-matching render — flagged as a risk in the report.
        Group {
            switch selectedTab {
            case .status:
                HomeView(
                    showsOnboarding: $showsAbout,
                    showsPaywall: $showsPaywall
                )
            case .regions:
                RegionsView(viewModel: container.regionsViewModel)
            }
        }
        .tint(Theme.Colors.tabSelected)
        .environment(\.redesignThemePalette, redesignPalette)
        .onAppear {
            #if DEBUG
                if AppLaunchArguments.showsPaywallOnLaunch {
                    showsPaywall = true
                }
            #endif
            container.mainTabViewModel.appear()
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
        .safeAreaInset(edge: .bottom) {
            // The region change notice floats above the bar (RD-4 brief, "region change notice
            // floats above the bar"), never under or beside it.
            VStack(spacing: Theme.Spacing.sm) {
                if let notice = regions.regionChangeNotice {
                    regionChangeNotice(notice)
                }
                RedesignBottomBar(
                    selectedTab: $selectedTab,
                    action: bottomBarAction,
                    palette: redesignPalette,
                    onActionTapped: performBottomBarAction
                )
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

    /// The round button's action: Refresh on Status (same action `HomeView` wires for the old
    /// button), opens search on Regions (RD-7).
    private func performBottomBarAction() {
        switch selectedTab {
        case .status:
            Task { await container.homeViewModel.refresh() }
        case .regions:
            container.regionsViewModel.activateSearch()
        }
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
