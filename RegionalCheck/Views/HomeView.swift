import DriveCheckKit
import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            showsLocationAccessDenied: container.homeViewModel.showsLocationAccessDenied,
            followsLocation: container.regions.followsLocation,
            secondaryRegion: container.homeViewModel.secondaryRegion,
            secondaryRegionStatus: container.homeViewModel.secondaryRegionStatus,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            debugExplanationTraces: container.explanationTraces,
            onOpenLocationSettings: {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
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
