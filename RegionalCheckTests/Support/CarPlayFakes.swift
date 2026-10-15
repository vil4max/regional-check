import DriveCheckKit
import Foundation
import Observation
@testable import RegionalCheck

/// A status store for CarPlay tests: it holds a snapshot and answers each refresh from a script
/// instead of a provider, so a test states the outcome rather than staging a network.
@MainActor
@Observable
final class FakeCarPlayStatus: CarPlayStatusRefreshing {
    var lastSnapshot: AlertsSnapshot?
    var currentRegion: AlertRegion
    var regionTitle: String
    var isLoading = false
    var hasRefreshFailed = false
    var isRateLimited = false
    var environment = RefreshEnvironment(
        isAlarmActive: false,
        isLowPowerModeEnabled: false,
        thermalState: .nominal,
        isExpensiveNetwork: false,
        isConstrainedNetwork: false
    )
    /// Whether each refresh fails; read once per refresh.
    var failsRefresh = false
    /// The snapshot a successful refresh stores.
    var refreshedSnapshot: AlertsSnapshot?
    /// Runs after each refresh has settled, with its 1-based number.
    @ObservationIgnored var afterRefresh: (Int) -> Void = { _ in }
    private(set) var refreshCount = 0

    init(region: AlertRegion = .kyivCity, snapshot: AlertsSnapshot? = nil) {
        currentRegion = region
        regionTitle = region.title
        lastSnapshot = snapshot
        refreshedSnapshot = snapshot
    }

    func refreshEnvironment() -> RefreshEnvironment {
        environment
    }

    func awaitStatusSettled() async {}

    func refresh(isScheduled _: Bool) async {
        refreshCount += 1
        if failsRefresh {
            hasRefreshFailed = true
        } else {
            hasRefreshFailed = false
            lastSnapshot = refreshedSnapshot
        }
        afterRefresh(refreshCount)
    }
}

@MainActor
@Observable
final class FakeCarPlayRegions: CarPlayRegionReading {
    var selectedRegion: AlertRegion
    var isOutsideUkraine = false

    init(region: AlertRegion = .kyivCity) {
        selectedRegion = region
    }
}

extension FixtureNetwork {
    /// A full feed snapshot with `alarmRegions` under alert, fetched at the fixture's fixed clock.
    static func snapshot(alarmRegions: Set<AlertRegion>, fetchedAt: Date = servedAt) -> AlertsSnapshot {
        FixtureNetwork(alarmRegions: alarmRegions).snapshot(fetchedAt: fetchedAt)
    }
}
