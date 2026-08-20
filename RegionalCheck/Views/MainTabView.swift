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
        let tabBar = UITabBar.appearance()
        tabBar.tintColor = UIColor.white
        tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.62)
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

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                showsOnboarding: $showsOnboarding,
                showsPaywall: $showsPaywall
            )
            .tabItem {
                Label("tab.status", systemImage: "steeringwheel")
            }
            .tag(Tab.status)

            RegionsView(viewModel: container.regionsViewModel)
                .tabItem {
                    Label("tab.regions", systemImage: "list.bullet")
                }
                .tag(Tab.regions)
        }
        .tint(Theme.Colors.tabSelected)
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
            if let notice = regions.regionChangeNotice {
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
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppContainer())
}
