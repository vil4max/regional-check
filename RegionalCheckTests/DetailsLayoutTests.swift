import Foundation
@testable import RegionalCheck
import Testing

/// The Details tab's blocks and the About rows (DETAILS-compact).
struct DetailsLayoutTests {
    @Test("REQ-REGION-009 Details is location (only when blocked), alerts, about; no summary block")
    func sectionsAreLocationAlertsAbout() {
        #expect(DetailsLayout.sections(isLocationBlocked: true) == [.location, .alerts, .about])
        #expect(DetailsLayout.sections(isLocationBlocked: false) == [.alerts, .about])
        #expect(DetailsSection.allCases == [.location, .alerts, .about])
    }

    @Test("REQ-SURF-007 About keeps the Pro row when offered and Manage Subscription only when active")
    func aboutRowsFollowPurchases() {
        #expect(
            DetailsLayout.aboutRows(showsPro: true, canManageSubscription: true)
                == [.pro, .restorePurchases, .manageSubscription, .dataSource, .disclaimer, .version])
        #expect(
            DetailsLayout.aboutRows(showsPro: false, canManageSubscription: false)
                == [.restorePurchases, .dataSource, .disclaimer, .version])
    }
}
