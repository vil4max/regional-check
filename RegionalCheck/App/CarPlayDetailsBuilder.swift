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

    /// Title caps names at 2 + "+N" (`nearbyNamesTitle`, shared with the Status tab); the
    /// detail is a count sentence only, never a second copy of the name list.
    private func nearbyItem() -> CPListItem? {
        let alerts = status.lastSnapshot?.statuses.compactMap { $0.value == .alarm ? $0.key : nil } ?? []
        let nearby = NearbyRegionPolicy.activeAlerts(near: status.currentRegion, among: alerts)
        guard !nearby.isEmpty else { return nil }
        return CPListItem(
            text: String(localized: "driver.status.nearby_prefix") + " " + nearbyNamesTitle(nearby),
            detailText: String(format: String(localized: "driver.nearby"), nearby.count)
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
            detailText: alertedRegions.isEmpty ? nil : ukraineAffectedListText(alertedRegions)
        )
        return CPListSection(
            items: [item],
            header: String(localized: "driver.details.section.ukraine"),
            sectionIndexTitle: nil
        )
    }

    /// At most 3 names, then "and N more" — never the full list (a full alert can name
    /// most of the country's 25 regions, which would make the row unreadable at a glance).
    private func ukraineAffectedListText(_ regions: [AlertRegion]) -> String {
        let shown = regions.prefix(3).map(\.title).joined(separator: ", ")
        let remaining = regions.count - min(3, regions.count)
        guard remaining > 0 else { return shown }
        return shown + " " + String(format: String(localized: "driver.details.and_more"), remaining)
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
