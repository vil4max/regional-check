/// The sections of the Details tab (DETAILS-compact, UI-simplify): the Settings-style groups a
/// driver changes. The country summary is not here: Status carries the region and its nearby row
/// (REQ-SURF-005).
enum DetailsSection: Hashable, CaseIterable {
    case location
    case alerts
    case notifications
    case about
}

/// Rows of the About section, top to bottom. The disclaimer and the version are its footer
/// (UI-simplify AC-8), not rows.
enum DetailsAboutRow: Hashable {
    case pro
    case restorePurchases
    case manageSubscription
    case dataSource
}

enum DetailsLayout {
    /// The location section appears only while access is blocked (REQ-REGION-009); Alerts always
    /// shows, because the Live Activities switch is always there; Notifications only when the app
    /// built its push controller (UI-simplify AC-6, AC-7).
    static func sections(isLocationBlocked: Bool, hasNotifications: Bool) -> [DetailsSection] {
        (isLocationBlocked ? [.location] : []) + [.alerts] + (hasNotifications ? [.notifications] : []) + [.about]
    }

    /// The Pro row only when it is offered or owned and Manage Subscription only with an active
    /// subscription, as before (REQ-SURF-007); Restore and the data source always.
    static func aboutRows(showsPro: Bool, canManageSubscription: Bool) -> [DetailsAboutRow] {
        var rows: [DetailsAboutRow] = showsPro ? [.pro] : []
        rows.append(.restorePurchases)
        if canManageSubscription {
            rows.append(.manageSubscription)
        }
        rows.append(.dataSource)
        return rows
    }
}
