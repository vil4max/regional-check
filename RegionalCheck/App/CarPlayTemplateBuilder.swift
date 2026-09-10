import CarPlay

/// Builds CarPlay templates from shared status, region, and subscription state.
/// Keeps template construction and rendering helpers out of the scene delegate
/// so the delegate can focus on lifecycle and observation.
@MainActor
struct CarPlayTemplateBuilder {
    private let status: StatusController
    private let statusDetails: StatusDetailsViewModel
    private let regions: RegionSelection
    private let subscription: SubscriptionManager
    private let location: LocationManager
    private let onRefresh: () async -> Void
    private let onShowDetails: (String) -> Void

    init(
        status: StatusController,
        statusDetails: StatusDetailsViewModel,
        regions: RegionSelection,
        subscription: SubscriptionManager,
        location: LocationManager,
        onRefresh: @escaping () async -> Void,
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

    func rootTemplate(state: StatusState, regionTitle: String) -> CPInformationTemplate {
        let content = CarPlayStatusContent.make(
            state: state,
            regionTitle: regionTitle,
            detailsState: statusDetails.presentationState
        )
        let mode = regions.followsLocation
            ? (regions.isOutsideUkraine ? String(localized: "driver.region.outside")
                : String(localized: "driver.region.automatic"))
            : String(localized: "driver.region.manual")
        var items = [CPInformationItem(title: content.regionTitle, detail: mode)]
        let historical = state.phase == .error || status.isDataStale
        if historical, let previous = status.lastKnownState {
            items.append(CPInformationItem(
                title: String(localized: "driver.last_status") + " " + previous.title,
                detail: previous.detailText
            ))
        } else if let detail = state.detailText {
            items.append(CPInformationItem(title: detail, detail: nil))
        }
        if location.isAuthorizationBlocked {
            items.append(
                CPInformationItem(
                    title: NSLocalizedString("location.access.denied.carplay", comment: ""),
                    detail: nil
                )
            )
        } else if !historical, state.phase == .quiet, let snapshot = status.lastSnapshot {
            let alerts = snapshot.statuses.compactMap { $0.value == .alarm ? $0.key : nil }
            let nearby = NearbyRegionPolicy.activeAlerts(near: status.currentRegion, among: alerts)
            if !nearby.isEmpty {
                items.append(CPInformationItem(
                    title: String(format: String(localized: "driver.nearby"), nearby.count), detail: nil
                ))
            }
        }

        let refresh = CPTextButton(
            title: status.isLoading ? String(localized: "Checking…") : String(localized: "Refresh"),
            textStyle: .normal
        ) { _ in
            Task { @MainActor in
                guard !status.isLoading else { return }
                await onRefresh()
            }
        }

        let details = CPTextButton(title: String(localized: "driver.details"), textStyle: .normal) { _ in
            onShowDetails(String(localized: "driver.details"))
        }
        return CPInformationTemplate(
            title: historical ? "? \(String(localized: "driver.no_current_data"))"
                : "\(statusMarker(for: state)) \(content.title)",
            layout: .leading,
            items: items,
            actions: [refresh, details]
        )
    }

    func detailItems() -> [CPInformationItem] {
        var rows = [CPInformationItem(title: status.regionTitle, detail: status.state.detailText)]
        if status.isDataStale || status.state.phase == .error {
            rows.append(CPInformationItem(title: String(localized: "driver.no_current_data"), detail: nil))
            if let previous = status.lastKnownState {
                rows.append(CPInformationItem(
                    title: String(localized: "driver.last_status") + " " + previous.title, detail: previous.detailText
                ))
            }
        } else {
            let content = CarPlayStatusContent.make(
                state: status.state, regionTitle: status.regionTitle, detailsState: statusDetails.presentationState
            )
            rows.append(contentsOf: content.detailRows.map { CPInformationItem(title: $0, detail: nil) })
        }
        if subscription.allows(.extendedDetail) {
            rows.append(CPInformationItem(
                title: String(localized: "status.source.label"),
                detail: StatusSourceLabel.displayName(for: status.lastSourceRaw)
            ))
        }
        return rows
    }

    private func statusMarker(for state: StatusState) -> String {
        switch state {
        case .alarm: "🚨"
        case .quiet: "🟢"
        case .idle: "↻"
        case .error, .regionUnavailable: "?"
        }
    }
}
