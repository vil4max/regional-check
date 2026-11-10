/// The sections of the Details tab (DETAILS-compact, UI-simplify), grouped by purpose: one row is
/// one setting, and a row mirroring a system setting sits right under the app setting it affects
/// (UI-simplify AC-11). The country summary is not here: Status carries the region and its nearby
/// row (REQ-SURF-005).
enum DetailsSection: Hashable, CaseIterable {
    case location
    case alerts
    case notifications
    /// iOS's notification settings for the app, under the switch they decide.
    case notificationSettings
    case purchases
    case about
}

/// Rows of the purchases section, top to bottom.
enum DetailsPurchaseRow: Hashable {
    case pro
    case restorePurchases
    case manageSubscription
}

/// Rows of the About section: information, not settings. The disclaimer is its footer.
enum DetailsAboutRow: Hashable, CaseIterable {
    case dataSource
    case version
}

enum DetailsLayout {
    /// The location section appears only while access is blocked (REQ-REGION-009); Alerts always
    /// shows, because the Live Activities switch is always there; the notification sections only
    /// when the app built its push controller (UI-simplify AC-6, AC-7).
    static func sections(isLocationBlocked: Bool, hasNotifications: Bool) -> [DetailsSection] {
        (isLocationBlocked ? [.location] : []) + [.alerts]
            + (hasNotifications ? [.notifications, .notificationSettings] : []) + [.purchases, .about]
    }

    /// The Pro row only when it is offered or owned and Manage Subscription only with an active
    /// subscription, as before (REQ-SURF-007); Restore always.
    static func purchaseRows(showsPro: Bool, canManageSubscription: Bool) -> [DetailsPurchaseRow] {
        var rows: [DetailsPurchaseRow] = showsPro ? [.pro] : []
        rows.append(.restorePurchases)
        if canManageSubscription {
            rows.append(.manageSubscription)
        }
        return rows
    }
}
