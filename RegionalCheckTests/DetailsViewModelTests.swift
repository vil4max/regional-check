import DriveCheckKit
import Foundation
@testable import RegionalCheck
import Testing

@MainActor
struct DetailsViewModelTests {
    @Test("REQ-REGION-009 Details reports blocked location access so it can offer Open Settings")
    func locationAccessFollowsTheLocationSource() {
        let location = FakeDetailsLocationSource()
        let sut = makeSUT(location: location)
        #expect(sut.isLocationAccessBlocked == false)

        location.isAuthorizationBlocked = true
        #expect(sut.isLocationAccessBlocked)
    }

    @Test("REQ-SURF-007 the Live Activity switch on Details is the user's own and needs no entitlement")
    func liveActivitySwitchIsForwardedWithoutAnEntitlement() {
        TestDefaults.withTemporaryDefaults { defaults in
            let subscription = SubscriptionManager(
                service: FakeSubscriptionService(products: [], entitlement: .none),
                cache: EntitlementCache(userDefaults: defaults),
                userDefaults: defaults,
                entitlementPersistence: SharedStore(userDefaults: defaults),
                widgetReloader: TestWidgetReloader()
            )
            var forwarded: [Bool] = []
            let sut = DetailsViewModel(
                location: FakeDetailsLocationSource(),
                subscription: subscription,
                setLiveActivityEnabled: { enabled in
                    forwarded.append(enabled)
                    subscription.setLiveActivityEnabled(enabled)
                }
            )

            sut.setLiveActivityEnabled(false)
            #expect(sut.isLiveActivityEnabled == false)
            sut.setLiveActivityEnabled(true)
            #expect(sut.isLiveActivityEnabled)
            #expect(forwarded == [false, true])
            #expect(subscription.isPro == false)
        }
    }

    @Test
    func versionLineCarriesTheVersionAndTheBuild() {
        let text = DetailsViewModel.versionBuildText(version: "3.0.0", build: "4")
        #expect(text.contains("3.0.0"))
        #expect(text.contains("4"))
    }

    private func makeSUT(location: FakeDetailsLocationSource) -> DetailsViewModel {
        DetailsViewModel(
            location: location,
            subscription: AppContainer.fixture().subscription,
            setLiveActivityEnabled: { _ in }
        )
    }
}

@MainActor
private final class FakeDetailsLocationSource: HomeLocationSource {
    var isAuthorizationBlocked = false
}
