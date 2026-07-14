import SwiftUI

struct HomeView: View {
    @State private var controller: StatusController
    @State private var regionListenerID: UUID?

    private var location: LocationManager { AppDependencies.location }
    private var regions: RegionSelection { AppDependencies.regions }

    @MainActor
    init(provider: any StatusProviding = AppDependencies.provider) {
        let region = AppDependencies.regions.selectedRegion
        _controller = State(initialValue: StatusController(region: region, provider: provider))
    }

    var body: some View {
        StatusView(controller: controller) {
            controller.refresh()
        }
        .onAppear {
            if regionListenerID == nil {
                regionListenerID = regions.addListener { region in
                    controller.setRegion(region)
                    controller.refresh()
                }
            }
            location.requestAuthorizationIfNeeded()
        }
        .onChange(of: location.coordinateStamp) { _, _ in
            guard let coordinate = location.coordinate else { return }
            regions.updateFromLocation(coordinate: coordinate)
        }
        .onDisappear {
            if let regionListenerID {
                regions.removeListener(regionListenerID)
                self.regionListenerID = nil
            }
        }
    }
}

#Preview {
    HomeView()
}
