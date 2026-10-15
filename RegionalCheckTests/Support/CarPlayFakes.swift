import CarPlay
import CoreLocation
import DriveCheckKit
import Foundation
import Observation
@testable import RegionalCheck

/// A status store for CarPlay tests: it holds a snapshot and answers each refresh from a script
/// instead of a provider, so a test states the outcome rather than staging a network.
@MainActor
@Observable
final class FakeCarPlayStatus: CarPlaySessionStatus {
    var state: StatusState = .idle
    var statusDetailsRevision: Int?
    private(set) var periodicRefreshBegins = 0
    private(set) var periodicRefreshEnds = 0
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

    func beginPeriodicRefresh() {
        periodicRefreshBegins += 1
    }

    func endPeriodicRefresh() {
        periodicRefreshEnds += 1
    }

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
final class FakeCarPlayRegions: CarPlayRegionFollowing {
    var selectedRegion: AlertRegion
    var isOutsideUkraine = false
    private(set) var forwardedFixes: [LocationFix] = []

    init(region: AlertRegion = .kyivCity) {
        selectedRegion = region
    }

    func updateFromLocation(fix: LocationFix) {
        forwardedFixes.append(fix)
    }
}

/// A location client that counts its begin and end calls; its permission is whatever a test sets.
@MainActor
@Observable
final class FakeCarPlayLocation: CarPlayLocationSource {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var lastFix: LocationFix?
    var coordinateStamp = 0
    private(set) var beginCount = 0
    private(set) var endCount = 0

    var isAuthorizationBlocked: Bool {
        LocationAuthorizationPolicy.isBlocked(authorizationStatus)
    }

    func beginUpdating() {
        beginCount += 1
    }

    func endUpdating() {
        endCount += 1
    }
}

/// Counts the CarPlay Live Activity session calls; everything else is inert.
@MainActor
final class CarPlayLiveActivitySpy: LiveActivityControlling {
    private(set) var carPlayBegins = 0
    private(set) var carPlayEnds = 0

    func beginPhoneForegroundSession() {}
    func endPhoneForegroundSession() {}

    func beginCarPlaySession() {
        carPlayBegins += 1
    }

    func endCarPlaySession() {
        carPlayEnds += 1
    }

    func update(
        phase _: DriveCheckActivityPhase,
        regionTitle _: String,
        checkedAt _: Date?,
        sourceLabel _: String,
        isStale _: Bool
    ) {}

    func endAll() {}
    func settle() async {}
}

/// Holds every installed root template strongly, as `CPInterfaceController` does: the scene
/// delegate keeps only a weak reference.
@MainActor
final class RootTemplateInstallerSpy: CarPlayRootTemplateInstalling {
    private(set) var installed: [CPTemplate] = []

    func installRootTemplate(_ rootTemplate: CPTemplate) {
        installed.append(rootTemplate)
    }
}

extension FixtureNetwork {
    /// A full feed snapshot with `alarmRegions` under alert, fetched at the fixture's fixed clock.
    static func snapshot(alarmRegions: Set<AlertRegion>, fetchedAt: Date = servedAt) -> AlertsSnapshot {
        FixtureNetwork(alarmRegions: alarmRegions).snapshot(fetchedAt: fetchedAt)
    }
}
