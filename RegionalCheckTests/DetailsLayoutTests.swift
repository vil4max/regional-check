import Foundation
@testable import RegionalCheck
import Testing

/// The Settings tab's sections and rows (DETAILS-compact, UI-simplify).
struct DetailsLayoutTests {
    @Test("UI-simplify AC-5 AC-11 REQ-REGION-009 sections by purpose; system mirrors right under their switch")
    func sectionsFollowLocationAndPush() {
        #expect(
            DetailsLayout.sections(isLocationBlocked: true, hasNotifications: true)
                == [.location, .alerts, .notifications, .notificationSettings, .about])
        #expect(
            DetailsLayout.sections(isLocationBlocked: false, hasNotifications: false)
                == [.alerts, .about])
        #expect(
            DetailsSection.allCases
                == [.location, .alerts, .notifications, .notificationSettings, .about])
    }

    @Test(
        "UI-simplify AC-8 REQ-SURF-007 About at the bottom: Pro if offered, Restore, Manage if active, source, version")
    func aboutRowsFollowPurchases() {
        #expect(
            DetailsLayout.aboutRows(showsPro: true, canManageSubscription: true)
                == [.pro, .restorePurchases, .manageSubscription, .dataSource, .version])
        #expect(
            DetailsLayout.aboutRows(showsPro: false, canManageSubscription: false)
                == [.restorePurchases, .dataSource, .version])
    }
}
