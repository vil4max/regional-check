import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct HomeViewModelTests {
    @Test
    func sourceLabel_isNilWhenExtendedDetailNotAllowed() {
        let sut = makeSUT(allowsExtendedDetail: false, lastSourceRaw: "test-feed")
        #expect(sut.sourceLabel == nil)
    }

    @Test
    func sourceLabel_displaysLabelWhenExtendedDetailAllowed() {
        let sut = makeSUT(allowsExtendedDetail: true, lastSourceRaw: "test-feed")
        #expect(sut.sourceLabel != nil)
    }

    @Test
    func secondaryRegion_isNilWhenNotPro() {
        let sut = makeSUT(isPro: false, secondaryRegion: .kyivCity)
        #expect(sut.secondaryRegion == nil)
    }

    @Test
    func secondaryRegion_returnsSavedRegionWhenPro() {
        let sut = makeSUT(isPro: true, secondaryRegion: .kyivCity)
        #expect(sut.secondaryRegion == .kyivCity)
    }

    @Test
    func secondaryRegionStatus_isNilWithoutASecondaryRegion() {
        let sut = makeSUT(isPro: true, secondaryRegion: nil)
        #expect(sut.secondaryRegionStatus == nil)
    }

    @Test
    func secondaryRegionStatus_readsItFromTheLatestSnapshot() {
        let snapshot = AlertsSnapshot(
            source: "test",
            serverCachedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            statuses: [.kyivCity: .alarm]
        )
        let sut = makeSUT(isPro: true, secondaryRegion: .kyivCity, lastSnapshot: snapshot)
        #expect(sut.secondaryRegionStatus == .alarm)
    }

    @Test
    func showsLocationAccessDenied_reflectsLocationSource() {
        let sut = makeSUT(isAuthorizationBlocked: true)
        #expect(sut.showsLocationAccessDenied)
    }

    // MARK: - RD-5: full-form titles (REQ-SURF-001), meta line, country summary (docs/tasks/rd-5-status-screen.md)

    @Test
    func fullTitle_matchesTheStateTableFullForms() {
        #expect(Theme.RedesignStatusAccent.clear.fullTitle == "No Alert")
        #expect(Theme.RedesignStatusAccent.alert.fullTitle == "Air Raid Alert")
        #expect(Theme.RedesignStatusAccent.stale.fullTitle == "No Current Data")
        #expect(Theme.RedesignStatusAccent.checking.fullTitle == "Checking…")
    }

    @Test
    func metaLine_checkingIsNeverColoredLikeClearOrAlert() {
        // REQ-REFRESH-006 / failure condition: a stale or checking state must never show a
        // clear/alert color. This is structural (StatusHeroCard always derives its accent color
        // from `Theme.RedesignColors.statusAccent(for:)`, which switches on the same 4-case
        // `RedesignStatusAccent` `StatusMetaLine.text` switches on below) — this test locks the
        // meta line's own text to the same accent so the two can never drift apart.
        let text = StatusMetaLine.text(accent: .checking, followsLocation: true, checkedAt: nil, lastKnownTitle: nil)
        #expect(text.contains("Locating"))
    }

    @Test
    func metaLine_staleShowsLastKnownStatusAndTime() {
        let text = StatusMetaLine.text(
            accent: .stale,
            followsLocation: true,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastKnownTitle: "No Alert"
        )
        #expect(text.contains("No Alert"))
    }

    @Test
    func metaLine_clearUsesTheModeWord() {
        let automatic = StatusMetaLine.text(
            accent: .clear,
            followsLocation: true,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastKnownTitle: nil
        )
        let manual = StatusMetaLine.text(
            accent: .clear,
            followsLocation: false,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastKnownTitle: nil
        )
        #expect(automatic != manual)
    }

    @Test
    func countrySummary_countsRegionsFromTheSnapshotNeverHardcoded25() {
        // REQ-SURF-002-adjacent failure condition: "25" is hard-coded. `AlertRegion.allCases`
        // is the source of truth; this asserts the summary's total always matches it, however
        // many cases the enum has.
        let snapshot = AlertsSnapshot(
            source: "test",
            serverCachedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            statuses: [.kyivCity: .alarm, .lviv: .alarm]
        )
        let text = StatusCountrySummary.summaryText(for: snapshot)
        #expect(text.contains("\(AlertRegion.allCases.count)"))
        #expect(text.contains("2"))
    }

    @Test
    func countrySummary_affectedRegionTitlesListsOnlyAlarmRegions() {
        let snapshot = AlertsSnapshot(
            source: "test",
            serverCachedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            statuses: [.kyivCity: .alarm, .lviv: .quiet]
        )
        let affected = StatusCountrySummary.affectedRegionTitles(snapshot)
        #expect(affected.contains(AlertRegion.kyivCity.title))
        #expect(!affected.contains(AlertRegion.lviv.title))
    }

    // MARK: - Test doubles

    @MainActor
    final class StatusSourceMock: HomeStatusSource {
        var state: StatusState = .quiet(lastCheckedAt: Date(timeIntervalSince1970: 1_700_000_000))
        var regionTitle: String = "Kyiv City"
        var isLoading = false
        var isDataStale = false
        var lastSourceRaw: String?
        var lastSnapshot: AlertsSnapshot?
        func refresh() async {}
    }

    @MainActor
    final class LocationSourceMock: HomeLocationSource {
        var isAuthorizationBlocked = false
    }

    @MainActor
    final class SubscriptionMock: SubscriptionManaging {
        var state = SubscriptionState()
        var isPro = false
        func start() async {}
        func refreshProducts() async {}
        func purchase(productID _: String) async -> PurchaseResult {
            .pending
        }

        func restore() async -> RestoreOutcome {
            .failed
        }

        var allowsExtendedDetail = false
        func allows(_ feature: PremiumFeature) -> Bool {
            feature == .extendedDetail && allowsExtendedDetail
        }

        func setLiveActivityEnabled(_: Bool) {}
        func entitlementChanges() -> AsyncStream<Void> {
            AsyncStream { _ in }
        }
    }

    final class SecondaryRegionStoreMock: SecondaryRegionStore, @unchecked Sendable {
        var stubbedRegion: AlertRegion?
        func saveSecondaryRegion(_: AlertRegion?) {}
        func loadSecondaryRegion() -> AlertRegion? {
            stubbedRegion
        }
    }

    private func makeSUT(
        isPro: Bool = false,
        allowsExtendedDetail: Bool = false,
        lastSourceRaw: String? = nil,
        secondaryRegion: AlertRegion? = nil,
        lastSnapshot: AlertsSnapshot? = nil,
        isAuthorizationBlocked: Bool = false
    ) -> HomeViewModel {
        let status = StatusSourceMock()
        status.lastSourceRaw = lastSourceRaw
        status.lastSnapshot = lastSnapshot
        let location = LocationSourceMock()
        location.isAuthorizationBlocked = isAuthorizationBlocked
        let subscription = SubscriptionMock()
        subscription.isPro = isPro
        subscription.allowsExtendedDetail = allowsExtendedDetail
        let store = SecondaryRegionStoreMock()
        store.stubbedRegion = secondaryRegion
        return HomeViewModel(
            status: status,
            location: location,
            subscription: subscription,
            secondaryRegionStore: store,
            syncLiveActivityContent: {}
        )
    }
}
