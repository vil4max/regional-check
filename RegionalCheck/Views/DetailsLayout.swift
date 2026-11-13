/// The sections of the Settings tab (DETAILS-compact, UI-simplify; named Details until
/// 2026-11-10), grouped by purpose: one row is
/// one setting, and a row mirroring a system setting sits right under the app setting it affects
/// (UI-simplify AC-11). The country summary is not here: Status carries the region and its nearby
/// row (REQ-SURF-005).
enum DetailsSection: Hashable, CaseIterable {
    case location
    case alerts
    case notifications
    /// iOS's notification settings for the app, under the switch they decide.
    case notificationSettings
    case about
}

/// Rows of the About group at the bottom, top to bottom: purchases, then information. The
/// disclaimer is its footer.
enum DetailsAboutRow: Hashable {
    case pro
    case restorePurchases
    case manageSubscription
    case dataSource
    /// MAP-native AC-8: the drawn map's outlines are CC BY 3.0 IGO, credited here.
    case mapSource
    case version
}

enum DetailsLayout {
    /// The location section appears only while access is blocked (REQ-REGION-009); Alerts always
    /// shows, because the Live Activities switch is always there; the notification sections only
    /// when the app built its push controller (UI-simplify AC-6, AC-7).
    static func sections(isLocationBlocked: Bool, hasNotifications: Bool) -> [DetailsSection] {
        (isLocationBlocked ? [.location] : []) + [.alerts]
            + (hasNotifications ? [.notifications, .notificationSettings] : []) + [.about]
    }

    /// The Pro row only when it is offered or owned and Manage Subscription only with an active
    /// subscription, as before (REQ-SURF-007); Restore, both sources and the version always.
    static func aboutRows(showsPro: Bool, canManageSubscription: Bool) -> [DetailsAboutRow] {
        var rows: [DetailsAboutRow] = showsPro ? [.pro] : []
        rows.append(.restorePurchases)
        if canManageSubscription {
            rows.append(.manageSubscription)
        }
        rows += [.dataSource, .mapSource, .version]
        return rows
    }
}
