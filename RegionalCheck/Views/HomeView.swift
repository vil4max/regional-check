import DriveCheckKit
import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(AppContainer.self) private var container

    @Binding var showsOnboarding: Bool
    @Binding var showsPaywall: Bool

    var body: some View {
        StatusView(
            controller: container.status,
            isPro: container.homeViewModel.isPro,
            sourceLabel: container.homeViewModel.sourceLabel,
            showsLocationAccessDenied: container.homeViewModel.showsLocationAccessDenied,
            secondaryRegionTitle: container.homeViewModel.secondaryRegionTitle,
            statusDetailsViewModel: container.statusDetailsViewModel,
            debugExplanationTraces: container.explanationTraces,
            onRefresh: {
                Task { await container.homeViewModel.refresh() }
            },
            onShowInfo: {
                showsOnboarding = true
            },
            onShowPaywall: {
                showsPaywall = true
            },
            onOpenLocationSettings: {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        )
        .onAppear {
            #if DEBUG
                if let phase = AppLaunchArguments.screenshotPhase {
                    container.status.applyScreenshotFixture(phase)
                }
            #endif
        }
    }
}

#Preview {
    HomeView(showsOnboarding: .constant(false), showsPaywall: .constant(false))
        .environment(AppContainer())
}
