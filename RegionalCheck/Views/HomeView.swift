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
        ZStack(alignment: .bottomTrailing) {
            StatusView(controller: controller)

            Button {
                controller.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(Theme.Typography.refreshSymbol)
                    .foregroundStyle(Theme.Colors.onFill)
                    .frame(width: Theme.Spacing.refreshControl, height: Theme.Spacing.refreshControl)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(controller.isLoading)
            .padding(Theme.Spacing.lg)
            .accessibilityLabel(Text("Refresh"))
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
