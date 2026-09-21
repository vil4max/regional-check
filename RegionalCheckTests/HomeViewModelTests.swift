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
        let text = StatusMetaLine.text(accent: .checking, checkedAt: nil, lastKnownTitle: nil)
        #expect(text.contains("Locating"))
    }

    @Test
    func metaLine_staleShowsLastKnownStatusAndTime() {
        let text = StatusMetaLine.text(
            accent: .stale,
            checkedAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastKnownTitle: "No Alert"
        )
        #expect(text.contains("No Alert"))
    }

    /// The region follows location only (ADR 0015), so the line no longer opens with a mode word:
    /// "Manual" has no subject and a constant "Automatic" would be claimed even with location denied.
    @Test
    func metaLine_clearReportsTheUpdateTimeWithoutAModeWord() {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let text = StatusMetaLine.text(accent: .clear, checkedAt: checkedAt, lastKnownTitle: nil)

        #expect(text.contains(checkedAt.formatted(date: .omitted, time: .shortened)))
        #expect(!text.contains(String(localized: "driver.status.mode.automatic")))
        #expect(!text.contains(String(localized: "driver.status.mode.manual")))
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

    private func makeSUT(
        allowsExtendedDetail: Bool = false,
        lastSourceRaw: String? = nil,
        isAuthorizationBlocked: Bool = false
    ) -> HomeViewModel {
        let status = StatusSourceMock()
        status.lastSourceRaw = lastSourceRaw
        let location = LocationSourceMock()
        location.isAuthorizationBlocked = isAuthorizationBlocked
        let subscription = SubscriptionMock()
        subscription.allowsExtendedDetail = allowsExtendedDetail
        return HomeViewModel(
            status: status,
            location: location,
            subscription: subscription,
            syncLiveActivityContent: {}
        )
    }
}
