import CarPlay
import DriveCheckKit

/// At most 2 names, then a "+N" badge suffix for the rest, so the nearby row stays readable at
/// a glance however many neighbors are under alert.
@MainActor
func nearbyNamesTitle(_ regions: [AlertRegion]) -> String {
    let shown = regions.prefix(2).map(\.title).joined(separator: ", ")
    let remaining = regions.count - min(2, regions.count)
    guard remaining > 0 else { return shown }
    return shown + " " + String(format: String(localized: "driver.status.nearby_more"), remaining)
}

/// Builds CarPlay's only screen, Status (REQ-SURF-006), from `CarPlayLoadState` plus shared
/// region and location state. Keeps template construction out of the scene delegate so the
/// delegate can focus on lifecycle and observation.
@MainActor
struct CarPlayTemplateBuilder {
    private let status: StatusController
    private let regions: RegionSelection
    private let location: any CarPlayLocationSource
    private let onRefresh: () -> Void

    init(
        status: StatusController,
        regions: RegionSelection,
        location: any CarPlayLocationSource,
        onRefresh: @escaping () -> Void
    ) {
        self.status = status
        self.regions = regions
        self.location = location
        self.onRefresh = onRefresh
    }

    /// REQ-SURF-001: full status form in the title (marker + full title); no marker when the
    /// shown status is not fresh (REQ-REFRESH-007). REQ-SURF-006: the rows are the region with its
    /// update time and, only when there is something to say, nearby alerts (REQ-SURF-005) or
    /// blocked location access; nothing else competes with the status for the driver's glance.
    func rootTemplate(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> CPInformationTemplate {
        let snapshot = loadState.snapshot
        let freshSnapshot = snapshot.flatMap { freshness.isFresh($0) ? $0 : nil }
        let items: [CPInformationItem] = if let freshSnapshot {
            freshRows(freshSnapshot)
        } else {
            staleRows(cached: snapshot, freshness: freshness)
        }

        let refresh = CPTextButton(
            title: loadState.isLoading ? String(localized: "Checking…") : String(localized: "Refresh"),
            textStyle: .normal
        ) { _ in
            Task { @MainActor in
                onRefresh()
            }
        }

        return CPInformationTemplate(
            title: title(loadState: loadState, freshSnapshot: freshSnapshot),
            layout: .leading,
            items: items,
            actions: [refresh]
        )
    }

    private func title(loadState: CarPlayLoadState, freshSnapshot: CarPlaySnapshot?) -> String {
        if let freshSnapshot {
            // REQ-SURF-010: the phone's yellow "be careful" status, with the traffic light's marker.
            if freshSnapshot.state.phase == .quiet,
               NearbyRegionPolicy.isSurrounded(status.currentRegion, snapshot: status.lastSnapshot)
            {
                return "🟡 " + String(localized: "status.caution.title")
            }
            return "\(CarPlayHeadline.marker(for: freshSnapshot.state)) \(fullStatusTitle(freshSnapshot.state))"
        }
        if loadState.isLoading {
            return String(localized: "driver.updating")
        }
        return String(localized: "driver.status.no_current_data.title")
    }

    private func fullStatusTitle(_ state: StatusState) -> String {
        state.phase == .alarm ? String(localized: "driver.status.full.alarm") : state.title
    }

    private func freshRows(_ snapshot: CarPlaySnapshot) -> [CPInformationItem] {
        var items = [CPInformationItem(title: status.regionTitle, detail: modeDetail(updated: snapshot.checkedAt))]
        if location.isAuthorizationBlocked {
            items.append(locationDeniedItem())
        } else if let nearby = nearbyItem() {
            items.append(nearby)
        }
        return items
    }

    private func staleRows(cached: CarPlaySnapshot?, freshness _: CarPlayFreshness) -> [CPInformationItem] {
        var items = [
            CPInformationItem(
                title: status.regionTitle,
                detail: modeDetail(updated: cached?.checkedAt, stale: true)
            ),
        ]
        if let cached {
            items.append(CPInformationItem(
                title: String(localized: "driver.last_status") + " " + cached.state.title,
                detail: String(localized: "status.stale")
            ))
        }
        if location.isAuthorizationBlocked {
            items.append(locationDeniedItem())
        }
        return items
    }

    /// `updated` is `nil` only when nothing has ever been fetched; the detail is then empty.
    private func modeDetail(updated: Date?, stale: Bool = false) -> String {
        if regions.isOutsideUkraine {
            return String(localized: "driver.region.outside")
        }
        // No mode word: the region follows location only, so "Automatic" distinguished nothing
        // and was claimed even with location denied (owner, 2026-09-21). The phone's meta line
        // dropped it for the same reason and shares its "Updated" string.
        guard let updated else { return "" }
        let time = updated.formatted(date: .omitted, time: .shortened)
        let format = stale
            ? String(localized: "driver.status.last_update")
            : String(localized: "status.meta.updated")
        return String(format: format, time)
    }

    /// `nil` when no neighbour is under alert: an empty "Nothing nearby" row is text the driver
    /// does not need (REQ-SURF-005, amended 2026-09-21).
    private func nearbyItem() -> CPInformationItem? {
        let alerts = status.lastSnapshot?.statuses.compactMap { $0.value == .alarm ? $0.key : nil } ?? []
        let nearby = NearbyRegionPolicy.activeAlerts(near: status.currentRegion, among: alerts)
        guard !nearby.isEmpty else { return nil }
        return CPInformationItem(
            title: String(localized: "driver.status.nearby_prefix") + " " + nearbyNamesTitle(nearby),
            detail: nil
        )
    }

    private func locationDeniedItem() -> CPInformationItem {
        CPInformationItem(
            title: NSLocalizedString("location.access.denied.carplay", comment: ""),
            detail: nil
        )
    }
}
