import CarPlay
import DriveCheckKit

/// Builds the CarPlay Details tab: YOUR REGION, UKRAINE, DATA (§7.2). REQ-SURF-006: free on
/// every row except the Pro-only source line. Reuses the Status-details wording keys
/// (`status.details.*`) that already match this copy; the affected-region list and the
/// UKRAINE count are computed directly from the shared snapshot, since the AI/deterministic
/// summary pipeline (`StatusDetailsProvider`) produces flowing sentences, not this row shape.
@MainActor
struct CarPlayDetailsBuilder {
    private let status: StatusController
    private let regions: RegionSelection
    private let subscription: SubscriptionManager

    init(status: StatusController, regions: RegionSelection, subscription: SubscriptionManager) {
        self.status = status
        self.regions = regions
        self.subscription = subscription
    }

    func detailsTemplate(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> CPListTemplate {
        let template = CPListTemplate(
            title: String(localized: "driver.details.tab_title"),
            sections: sections(loadState: loadState, freshness: freshness)
        )
        template.tabTitle = String(localized: "driver.details.tab_title")
        template.tabImage = UIImage(systemName: "list.bullet")
        // Nothing has ever been fetched: no per-region content to show yet.
        template.emptyViewTitleVariants = [String(localized: "driver.status.no_current_data.title")]
        return template
    }

    func sections(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> [CPListSection] {
        guard let snapshot = loadState.snapshot else { return [] }
        let isFresh = freshness.isFresh(snapshot)
        return [
            yourRegionSection(snapshot),
            ukraineSection(),
            dataSection(snapshot, isFresh: isFresh)
        ]
    }

    private func yourRegionSection(_ snapshot: CarPlaySnapshot) -> CPListSection {
        let isAlarm = snapshot.state.phase == .alarm
        let statusFragment = isAlarm
            ? String(localized: "driver.details.region_status.alarm")
            : String(localized: "driver.details.region_status.quiet")
        let regionItem = CPListItem(
            text: String(format: String(localized: "status.details.region_format"), status.regionTitle, statusFragment),
            detailText: isAlarm
                ? String(localized: "status.details.region_alarm")
                : String(localized: "status.details.region_quiet")
        )
        var items = [regionItem]
        if let nearby = nearbyItem() {
            items.append(nearby)
        }
        return CPListSection(
            items: items,
            header: String(localized: "driver.details.section.your_region"),
            sectionIndexTitle: nil
        )
    }

    /// Mirrors `StatusDetailsProvider`'s nearby-warning truncation (first 2 names, "and N more").
    private func nearbyItem() -> CPListItem? {
        let alerts = status.lastSnapshot?.statuses.compactMap { $0.value == .alarm ? $0.key : nil } ?? []
        let nearby = NearbyRegionPolicy.activeAlerts(near: status.currentRegion, among: alerts)
        guard !nearby.isEmpty else { return nil }
        let shown = nearby.prefix(2).map(\.title).joined(separator: ", ")
        let remaining = nearby.count - min(2, nearby.count)
        let detail = remaining > 0
            ? String(format: String(localized: "status.details.nearby_alerts_more"), shown, remaining)
            : String(format: String(localized: "status.details.nearby_alerts"), shown)
        return CPListItem(
            text: String(localized: "driver.status.nearby_prefix") + " " + nearby.map(\.title).joined(separator: ", "),
            detailText: detail
        )
    }

    private func ukraineSection() -> CPListSection {
        // Iterate `allCases` (a fixed array), not the snapshot dictionary directly: dictionary
        // iteration order is not deterministic, which would reshuffle this list between launches.
        let statuses = status.lastSnapshot?.statuses ?? [:]
        let alertedRegions = AlertRegion.allCases.filter { statuses[$0] == .alarm }
        let item = CPListItem(
            text: String(
                format: String(localized: "driver.details.alerts_count"),
                alertedRegions.count,
                AlertRegion.allCases.count
            ),
            detailText: alertedRegions.isEmpty ? nil : alertedRegions.map(\.title).joined(separator: ", ")
        )
        return CPListSection(
            items: [item],
            header: String(localized: "driver.details.section.ukraine"),
            sectionIndexTitle: nil
        )
    }

    private func regionModeText() -> String {
        if regions.followsLocation {
            return regions.isOutsideUkraine
                ? String(localized: "driver.region.outside")
                : String(localized: "driver.region.automatic")
        }
        return String(localized: "driver.region.manual")
    }

    private func dataSection(_ snapshot: CarPlaySnapshot, isFresh: Bool) -> CPListSection {
        let time = snapshot.checkedAt.formatted(date: .omitted, time: .shortened)
        let title = isFresh
            ? String(format: String(localized: "driver.details.updated_current"), time)
            : String(format: String(localized: "driver.details.updated_stale"), time)
        var detail = regionModeText()
        if subscription.allows(.extendedDetail) {
            detail += " · " + String(localized: "status.source.label") + " "
                + StatusSourceLabel.displayName(for: status.lastSourceRaw)
        }
        return CPListSection(
            items: [CPListItem(text: title, detailText: detail)],
            header: String(localized: "driver.details.section.data"),
            sectionIndexTitle: nil
        )
    }
}
