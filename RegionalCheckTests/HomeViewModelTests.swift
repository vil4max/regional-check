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
    func secondaryRegionTitle_isNilWhenNotPro() {
        let sut = makeSUT(isPro: false, secondaryRegion: .kyivCity)
        #expect(sut.secondaryRegionTitle == nil)
    }

    @Test
    func secondaryRegionTitle_returnsFormattedStringWhenProAndRegionSaved() {
        let sut = makeSUT(isPro: true, secondaryRegion: .kyivCity)
        #expect(sut.secondaryRegionTitle != nil)
        #expect(sut.secondaryRegionTitle?.contains("Kyiv") == true)
    }

    @Test
    func showsLocationAccessDenied_reflectsLocationSource() {
        let sut = makeSUT(isAuthorizationBlocked: true)
        #expect(sut.showsLocationAccessDenied)
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
        func purchase(productID _: String) async -> PurchaseResult { .pending }
        func restore() async -> RestoreOutcome { .failed }
        func allows(_ feature: PremiumFeature) -> Bool { feature == .extendedDetail }
        func setLiveActivityEnabled(_: Bool) {}
        func entitlementChanges() -> AsyncStream<Void> { AsyncStream { _ in } }
    }

    final class SecondaryRegionStoreMock: SecondaryRegionStore, @unchecked Sendable {
        var stubbedRegion: AlertRegion?
        func saveSecondaryRegion(_: AlertRegion?) {}
        func loadSecondaryRegion() -> AlertRegion? { stubbedRegion }
    }

    private func makeSUT(
        isPro: Bool = false,
        allowsExtendedDetail: Bool = false,
        lastSourceRaw: String? = nil,
        secondaryRegion: AlertRegion? = nil,
        isAuthorizationBlocked: Bool = false
    ) -> HomeViewModel {
        let status = StatusSourceMock()
        status.lastSourceRaw = lastSourceRaw
        let location = LocationSourceMock()
        location.isAuthorizationBlocked = isAuthorizationBlocked
        let subscription = SubscriptionMock()
        subscription.isPro = isPro
        if allowsExtendedDetail {
            subscription.allows = { _ in true }
        }
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
