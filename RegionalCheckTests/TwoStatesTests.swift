import CarPlay
import CoreLocation
import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

/// STATUS-two-states: a quiet region is "No Alert" in green whatever its neighbours do; the
/// neighbours are a note, never a status of their own.
@MainActor
@Suite(.removesDefaultsSuites)
struct TwoStatesTests {
    /// Kyiv Oblast under alert used to put Kyiv city on "Stay Alert" by itself; with three of its
    /// five neighbours under alert any region was "surrounded".
    private static let surroundingKyiv: Set<AlertRegion> = [.kyivOblast, .chernihiv, .zhytomyr]

    private func app(
        _ suite: String, authorization: CLAuthorizationStatus = .notDetermined
    ) async -> AppContainer {
        let app = AppContainer.fixture(
            region: .kyivCity,
            network: FixtureNetwork(alarmRegions: Self.surroundingKyiv),
            defaultsSuite: TestDefaults.fixtureSuite(suite),
            locationAuthorization: authorization
        )
        await app.status.refresh()
        return app
    }

    private func carPlayTemplate(_ app: AppContainer) -> CPInformationTemplate {
        let builder = CarPlayTemplateBuilder(
            status: app.status, regions: app.regions, location: app.location, onRefresh: {})
        let loaded =
            CarPlayRefreshCoordinator.cachedSnapshot(from: app.status).map { CarPlayLoadState.loaded($0) }
            ?? .failed(cached: nil)
        let freshness = CarPlayFreshness(
            now: AppContainer.fixtureNow,
            refreshIntervalSeconds: RefreshPolicy.baseIntervalSeconds(for: app.status.refreshEnvironment())
        )
        return builder.rootTemplate(loadState: loaded, freshness: freshness)
    }

    @Test("STATUS-two-states AC-1 the phone shows a surrounded quiet region as No Alert in green")
    func phoneIsNoAlert() async {
        let app = await app("two-states-phone")
        #expect(app.status.state.phase == .quiet)
        #expect(app.status.accent == .clear)
        #expect(app.status.presentation.titleKey == "All Clear")
        #expect(app.status.presentation.symbolName == "checkmark.shield.fill")
    }

    @Test("STATUS-two-states AC-1 AC-2 CarPlay titles it No Alert and keeps the nearby row")
    func carPlayIsNoAlertWithTheNote() async {
        let app = await app("two-states-carplay")
        let template = carPlayTemplate(app)
        #expect(template.title == "\(CarPlayHeadline.marker(for: app.status.state)) \(app.status.state.title)")
        #expect(!template.title.contains("🟡"))
        let nearby = NearbyAlertsLine.text(region: .kyivCity, snapshot: app.status.lastSnapshot)
        #expect(nearby != nil)
        #expect(template.items.contains { $0.title == nearby })
    }

    @Test("STATUS-two-states AC-4 with location denied CarPlay still names the neighbours under alert")
    func carPlayKeepsTheNoteWithLocationDenied() async {
        let app = await app("two-states-denied", authorization: .denied)
        let titles = carPlayTemplate(app).items.compactMap(\.title)
        #expect(titles.contains(String(localized: "location.access.denied.carplay")))
        #expect(titles.contains { $0 == NearbyAlertsLine.text(region: .kyivCity, snapshot: app.status.lastSnapshot) })
    }

    @Test("STATUS-two-states AC-5 alarm stays red and stale data stays grey")
    func otherStatesAreUnchanged() {
        #expect(Theme.RedesignStatusAccent(phase: .alarm, isStale: false) == .alert)
        #expect(Theme.RedesignStatusAccent(phase: .quiet, isStale: true) == .stale)
        #expect(Theme.RedesignStatusAccent(phase: .quiet, isStale: false) == .clear)
    }
}
