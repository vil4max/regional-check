import CarPlay

/// Builds CarPlay templates from `CarPlayLoadState` plus shared region and subscription state.
/// Keeps template construction and rendering helpers out of the scene delegate
/// so the delegate can focus on lifecycle and observation.
@MainActor
struct CarPlayTemplateBuilder {
    private let status: StatusController
    private let statusDetails: StatusDetailsViewModel
    private let regions: RegionSelection
    private let subscription: SubscriptionManager
    private let location: LocationManager
    private let onRefresh: () -> Void
    private let onShowDetails: (String) -> Void

    init(
        status: StatusController,
        statusDetails: StatusDetailsViewModel,
        regions: RegionSelection,
        subscription: SubscriptionManager,
        location: LocationManager,
        onRefresh: @escaping () -> Void,
        onShowDetails: @escaping (String) -> Void
    ) {
        self.status = status
        self.statusDetails = statusDetails
        self.regions = regions
        self.subscription = subscription
        self.location = location
        self.onRefresh = onRefresh
        self.onShowDetails = onShowDetails
    }

    func rootTemplate(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> CPInformationTemplate {
        let mode = regions.followsLocation
            ? (regions.isOutsideUkraine ? String(localized: "driver.region.outside")
                : String(localized: "driver.region.automatic"))
            : String(localized: "driver.region.manual")
        var items = [CPInformationItem(title: status.regionTitle, detail: mode)]
        let snapshot = loadState.snapshot
        let freshSnapshot = snapshot.flatMap { freshness.isFresh($0) ? $0 : nil }
        if let freshSnapshot {
            if let detail = freshSnapshot.state.detailText {
                items.append(CPInformationItem(title: detail, detail: nil))
            }
        } else if let snapshot {
            items.append(lastStatusItem(snapshot, freshness: freshness))
        } else if case .failed = loadState, let detail = StatusState.error.detailText {
            items.append(CPInformationItem(title: detail, detail: nil))
        }
        if location.isAuthorizationBlocked {
            items.append(
                CPInformationItem(
                    title: NSLocalizedString("location.access.denied.carplay", comment: ""),
                    detail: nil
                )
            )
        } else if freshSnapshot?.state.phase == .quiet, let lastSnapshot = status.lastSnapshot {
            let alerts = lastSnapshot.statuses.compactMap { $0.value == .alarm ? $0.key : nil }
            let nearby = NearbyRegionPolicy.activeAlerts(near: status.currentRegion, among: alerts)
            if !nearby.isEmpty {
                items.append(CPInformationItem(
                    title: String(format: String(localized: "driver.nearby"), nearby.count), detail: nil
                ))
            }
        }

        let refresh = CPTextButton(
            title: loadState.isLoading ? String(localized: "Checking…") : String(localized: "Refresh"),
            textStyle: .normal
        ) { _ in
            Task { @MainActor in
                onRefresh()
            }
        }

        let details = CPTextButton(title: String(localized: "driver.details"), textStyle: .normal) { _ in
            onShowDetails(String(localized: "driver.details"))
        }
        return CPInformationTemplate(
            title: CarPlayHeadline.title(for: loadState, freshness: freshness),
            layout: .leading,
            items: items,
            actions: [refresh, details]
        )
    }

    func detailItems(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> [CPInformationItem] {
        let snapshot = loadState.snapshot
        var rows = [CPInformationItem(title: status.regionTitle, detail: snapshot?.state.detailText)]
        if let snapshot, freshness.isFresh(snapshot) {
            let content = CarPlayStatusContent.make(
                state: snapshot.state, regionTitle: status.regionTitle, detailsState: statusDetails.presentationState
            )
            rows.append(contentsOf: content.detailRows.map { CPInformationItem(title: $0, detail: nil) })
        } else {
            let headline = loadState.isLoading
                ? String(localized: "driver.updating")
                : String(localized: "driver.no_current_data")
            rows.append(CPInformationItem(title: headline, detail: nil))
            if let snapshot {
                rows.append(lastStatusItem(snapshot, freshness: freshness))
            }
        }
        if subscription.allows(.extendedDetail) {
            rows.append(CPInformationItem(
                title: String(localized: "status.source.label"),
                detail: StatusSourceLabel.displayName(for: status.lastSourceRaw)
            ))
        }
        return rows
    }

    /// Stale data carries its age and no status marker so it cannot read as current.
    private func lastStatusItem(_ snapshot: CarPlaySnapshot, freshness: CarPlayFreshness) -> CPInformationItem {
        CPInformationItem(
            title: String(localized: "driver.last_status") + " "
                + CarPlayHeadline.agedStatus(snapshot, freshness: freshness),
            detail: snapshot.state.detailText
        )
    }
}
