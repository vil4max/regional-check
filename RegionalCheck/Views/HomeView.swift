import DriveCheckKit
import SwiftUI
import UIKit

/// The Status tab's root. It owns the tab's `NavigationStack` so the region list pushes inside
/// the tab — back navigation and the tab bar come from the system (ADR 0015).
struct HomeView: View {
    enum Route: Hashable {
        case regionList
    }

    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route]

    /// `initialPath` exists for the DEBUG `region-list` screenshot phase; production starts at the root.
    init(initialPath: [Route] = []) {
        _path = State(initialValue: initialPath)
    }

    var body: some View {
        NavigationStack(path: $path) {
            statusRoot
                // The Status tab draws its own floating title (`StatusToolbar`); the system bar
                // would stack a second one above it. The title still names the back button.
                .navigationTitle("tab.status")
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .regionList:
                        RegionListView(viewModel: container.regionListViewModel)
                    }
                }
        }
    }

    private var statusRoot: some View {
        StatusView(
            controller: container.status,
            showsLocationAccessDenied: container.homeViewModel.showsLocationAccessDenied,
            mapViewModel: container.mapViewModel,
            debugExplanationTraces: container.explanationTraces,
            onOpenLocationSettings: {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            },
            onOpenRegionList: {
                // Assigned, not appended: a second tap landing before the push animates must
                // not stack a second copy of the list.
                path = [.regionList]
            },
            onRefresh: {
                await container.homeViewModel.refresh()
            }
        )
        .onAppear {
            #if DEBUG
                if let phase = AppLaunchArguments.screenshotPhase {
                    container.status.applyScreenshotFixture(phase)
                }
            #endif
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await container.homeViewModel.refresh()
        }
    }
}

#if DEBUG
    #Preview("Home all clear") {
        HomeView()
            .environment(AppContainer.fixture())
    }

    #Preview("Home alert") {
        HomeView()
            .environment(AppContainer.fixture(region: .kharkiv))
    }
#endif
