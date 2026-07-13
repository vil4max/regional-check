import Foundation
import RegionalCheckData
import RegionalCheckStatus
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    let locationManager: UserLocationManager
    let regionSelection: RegionSelectionViewModel
    let alertViewModel: RegionalCheckViewModel

    private var didStart = false

    init(provider: UbillingAirAlertProvider = sharedProvider) {
        self.locationManager = UserLocationManager()

        let fetchStatus = FetchAlertStatusUseCase(provider: provider)
        let alertVM = RegionalCheckViewModel(region: .kyivCity, fetchStatus: fetchStatus)
        self.alertViewModel = alertVM

        self.regionSelection = RegionSelectionViewModel { region, _ in
            Task { @MainActor in
                alertVM.setRegion(region)
                alertVM.refresh()
            }
        }
    }

    func onAppear() {
        locationManager.requestAuthorizationIfNeeded()

        guard !didStart else { return }
        didStart = true
        alertViewModel.refresh()
    }

    func refresh() {
        alertViewModel.refresh()
    }
}
