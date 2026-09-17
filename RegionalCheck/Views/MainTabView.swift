import SwiftUI
import UIKit

struct MainTabView: View {
    enum Tab: Hashable {
        case status
        case regions
    }

    @Environment(AppContainer.self) private var container

    @AppStorage("hasCompletedOnboarding") private var hasSeenFirstLaunchInfo = false
    @State private var selectedTab: Tab
    @State private var showsOnboarding = false
    @State private var showsPaywall = false

    init(initialTab: Tab = .status) {
        _selectedTab = State(initialValue: initialTab)
    }

    private var controller: StatusController {
        container.status
    }

    private var location: LocationManager {
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
                    showsOnboarding: $showsOnboarding,
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
        .fullScreenCover(isPresented: $showsOnboarding) {
            OnboardingView(
                purpose: .about,
                isPro: subscription.isPro,
                isLiveActivityEnabled: subscription.state.isLiveActivityEnabled,
                onToggleLiveActivity: { enabled in
                    container.mainTabViewModel.setLiveActivityEnabled(enabled)
                },
                onContinue: {
                    AlternateIconManager.sync(isPro: subscription.isPro)
                    showsOnboarding = false
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
        .sheet(isPresented: Binding(
            get: {
                #if DEBUG
                    if AppLaunchArguments.screenshotPhase != nil {
                        return false
                    }
                #endif
                return !hasSeenFirstLaunchInfo
            },
            set: { isPresented in
                if !isPresented {
                    hasSeenFirstLaunchInfo = true
                }
            }
        )) {
            OutsideUkraineInfoSheet {
                hasSeenFirstLaunchInfo = true
            }
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
    /// button), a Search entry point on Regions. `RegionsView.swift`/`RegionsViewModel.swift`
    /// aren't owned by RD-4 (RD-7 builds the actual search), so this is a no-op placeholder for now
    /// — the button stays reachable and correctly labeled, per the brief's failure condition that
    /// it must never be hidden or unreachable.
    private func performBottomBarAction() {
        switch selectedTab {
        case .status:
            Task { await container.homeViewModel.refresh() }
        case .regions:
            break
        }
    }
}

#if DEBUG
    #Preview("Main tabs") {
        MainTabView()
            .environment(AppContainer.fixture())
    }
#endif
