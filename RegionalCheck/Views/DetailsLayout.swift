/// The order of the Details tab (DETAILS-compact): settings a driver changes, in few blocks. The
/// country summary is not here: Status carries the region and its nearby line (REQ-SURF-005).
enum DetailsSection: Hashable, CaseIterable {
    case location
    case alerts
    case about
}

/// Rows of the About block, top to bottom.
enum DetailsAboutRow: Hashable {
    case pro
    case restorePurchases
    case manageSubscription
    case dataSource
    case disclaimer
    case version
}

enum DetailsLayout {
    /// The location row appears only while access is blocked (REQ-REGION-009); Alerts always shows,
    /// because the Live Activity switch is always there.
    static func sections(isLocationBlocked: Bool) -> [DetailsSection] {
        (isLocationBlocked ? [.location] : []) + [.alerts, .about]
    }

    /// The Pro row only when it is offered or owned and Manage Subscription only with an active
    /// subscription, as before (REQ-SURF-007); Restore, the source, the disclaimer and the version
    /// always.
    static func aboutRows(showsPro: Bool, canManageSubscription: Bool) -> [DetailsAboutRow] {
        var rows: [DetailsAboutRow] = showsPro ? [.pro] : []
        rows.append(.restorePurchases)
        if canManageSubscription {
            rows.append(.manageSubscription)
        }
        rows += [.dataSource, .disclaimer, .version]
        return rows
    }
}
