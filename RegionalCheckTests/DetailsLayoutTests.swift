import Foundation
@testable import RegionalCheck
import Testing

/// The Details tab's blocks and the About rows (DETAILS-compact).
struct DetailsLayoutTests {
    @Test("DETAILS-compact AC-1 AC-2 AC-5 REQ-REGION-009 sections: location when blocked, alerts, about")
    func sectionsAreLocationAlertsAbout() {
        #expect(DetailsLayout.sections(isLocationBlocked: true) == [.location, .alerts, .about])
        #expect(DetailsLayout.sections(isLocationBlocked: false) == [.alerts, .about])
        #expect(DetailsSection.allCases == [.location, .alerts, .about])
    }

    @Test("DETAILS-compact AC-5 REQ-SURF-007 About: Pro if offered, Restore, Manage if active, source, version")
    func aboutRowsFollowPurchases() {
        #expect(
            DetailsLayout.aboutRows(showsPro: true, canManageSubscription: true)
                == [.pro, .restorePurchases, .manageSubscription, .dataSource, .disclaimer, .version])
        #expect(
            DetailsLayout.aboutRows(showsPro: false, canManageSubscription: false)
                == [.restorePurchases, .dataSource, .disclaimer, .version])
    }
}
