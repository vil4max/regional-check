import Foundation
@testable import RegionalCheck
import Testing

/// The Details tab's sections and the About rows (DETAILS-compact, UI-simplify).
struct DetailsLayoutTests {
    @Test("UI-simplify AC-5 AC-6 AC-7 REQ-REGION-009 sections: location when blocked, alerts, notifications, about")
    func sectionsFollowLocationAndPush() {
        #expect(
            DetailsLayout.sections(isLocationBlocked: true, hasNotifications: true)
                == [.location, .alerts, .notifications, .about])
        #expect(
            DetailsLayout.sections(isLocationBlocked: false, hasNotifications: true) == [
                .alerts, .notifications, .about,
            ])
        #expect(DetailsLayout.sections(isLocationBlocked: false, hasNotifications: false) == [.alerts, .about])
        #expect(DetailsSection.allCases == [.location, .alerts, .notifications, .about])
    }

    @Test("UI-simplify AC-8 REQ-SURF-007 About: Pro if offered, Restore, Manage if active, source; no footer rows")
    func aboutRowsFollowPurchases() {
        #expect(
            DetailsLayout.aboutRows(showsPro: true, canManageSubscription: true)
                == [.pro, .restorePurchases, .manageSubscription, .dataSource])
        #expect(
            DetailsLayout.aboutRows(showsPro: false, canManageSubscription: false)
                == [.restorePurchases, .dataSource])
    }
}
