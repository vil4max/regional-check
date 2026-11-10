import Foundation
@testable import RegionalCheck
import Testing

/// The Details tab's sections and rows (DETAILS-compact, UI-simplify).
struct DetailsLayoutTests {
    @Test("UI-simplify AC-5 AC-11 REQ-REGION-009 sections by purpose; system mirrors right under their switch")
    func sectionsFollowLocationAndPush() {
        #expect(
            DetailsLayout.sections(isLocationBlocked: true, hasNotifications: true)
                == [.location, .alerts, .notifications, .notificationSettings, .purchases, .about])
        #expect(
            DetailsLayout.sections(isLocationBlocked: false, hasNotifications: false)
                == [.alerts, .purchases, .about])
        #expect(
            DetailsSection.allCases
                == [.location, .alerts, .notifications, .notificationSettings, .purchases, .about])
    }

    @Test("UI-simplify AC-8 REQ-SURF-007 purchases: Pro if offered, Restore, Manage if active")
    func purchaseRowsFollowPurchases() {
        #expect(
            DetailsLayout.purchaseRows(showsPro: true, canManageSubscription: true)
                == [.pro, .restorePurchases, .manageSubscription])
        #expect(DetailsLayout.purchaseRows(showsPro: false, canManageSubscription: false) == [.restorePurchases])
    }

    @Test("UI-simplify AC-8 AC-11 About holds information only: the data source and the version")
    func aboutRowsAreInformation() {
        #expect(DetailsAboutRow.allCases == [.dataSource, .version])
    }
}
