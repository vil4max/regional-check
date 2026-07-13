import RegionalCheckStatus
import SwiftUI

struct ContentView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RegionalCheckStatusView(viewModel: coordinator.alertViewModel)

            Button {
                coordinator.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.onFill)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(coordinator.alertViewModel.isLoading)
            .padding(Theme.Spacing.lg)
            .accessibilityLabel(Text("Refresh"))
        }
        .onAppear {
            coordinator.onAppear()
        }
        .onChange(of: coordinator.locationManager.coordinateStamp) { _, _ in
            guard let coordinate = coordinator.locationManager.coordinate else { return }
            coordinator.regionSelection.updateFromLocation(coordinate: coordinate)
            coordinator.locationManager.stop()
        }
    }
}

#Preview {
    ContentView(coordinator: AppCoordinator())
}
