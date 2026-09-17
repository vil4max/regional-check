import CarPlay
import DriveCheckKit

/// At most 2 names, then a "+N" badge suffix for the rest — shared by the Status tab's and
/// Details tab's nearby rows so the two never disagree on how many names to spell out.
@MainActor
func nearbyNamesTitle(_ regions: [AlertRegion]) -> String {
    let shown = regions.prefix(2).map(\.title).joined(separator: ", ")
    let remaining = regions.count - min(2, regions.count)
    guard remaining > 0 else { return shown }
    return shown + " " + String(format: String(localized: "driver.status.nearby_more"), remaining)
}

/// Builds the CarPlay Status tab from `CarPlayLoadState` plus shared region and subscription
/// state. Keeps template construction out of the scene delegate so the delegate can focus on
/// lifecycle and observation. The Details tab is built separately by `CarPlayDetailsBuilder`.
@MainActor
struct CarPlayTemplateBuilder {
    private let status: StatusController
    private let regions: RegionSelection
    private let location: LocationManager
    private let onRefresh: () -> Void

    init(
        status: StatusController,
        regions: RegionSelection,
        location: LocationManager,
        onRefresh: @escaping () -> Void
    ) {
        self.status = status
        self.regions = regions
        self.location = location
        self.onRefresh = onRefresh
    }

    /// REQ-SURF-001: full status form in the title (marker + full title); no marker when the
    /// shown status is not fresh (REQ-REFRESH-007). REQ-SURF-005: the nearby row shows in both
    /// the quiet and the alarm phase, not only when quiet.
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
        let isAlarm = snapshot.state.phase == .alarm
        items.append(CPInformationItem(
            title: isAlarm
                ? String(localized: "driver.status.region_sentence.alarm")
                : String(localized: "driver.status.region_sentence.quiet"),
            detail: alertsCountDetail()
        ))
        if location.isAuthorizationBlocked {
            items.append(locationDeniedItem())
        } else {
            items.append(nearbyItem())
        }
        return items
    }

    private func staleRows(cached: CarPlaySnapshot?, freshness _: CarPlayFreshness) -> [CPInformationItem] {
        var items = [CPInformationItem(
            title: status.regionTitle,
            detail: modeDetail(updated: cached?.checkedAt, stale: true)
        )]
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

    /// `updated` is `nil` only when nothing has ever been fetched; the mode word is shown alone.
    private func modeDetail(updated: Date?, stale: Bool = false) -> String {
        if regions.followsLocation, regions.isOutsideUkraine {
            return String(localized: "driver.region.outside")
        }
        let mode = regions.followsLocation
            ? String(localized: "driver.status.mode.automatic")
            : String(localized: "driver.status.mode.manual")
        guard let updated else { return mode }
        let time = updated.formatted(date: .omitted, time: .shortened)
        let format = stale
            ? String(localized: "driver.status.mode_last_update")
            : String(localized: "driver.status.mode_updated")
        return String(format: format, mode, time)
    }

    private func alertsCountDetail() -> String {
        let count = status.lastSnapshot?.statuses.values.filter { $0 == .alarm }.count ?? 0
        return String(format: String(localized: "driver.status.alerts_count"), count, AlertRegion.allCases.count)
    }

    private func nearbyItem() -> CPInformationItem {
        let alerts = status.lastSnapshot?.statuses.compactMap { $0.value == .alarm ? $0.key : nil } ?? []
        let nearby = NearbyRegionPolicy.activeAlerts(near: status.currentRegion, among: alerts)
        guard !nearby.isEmpty else {
            return CPInformationItem(
                title: String(localized: "driver.status.nothing_nearby"),
                detail: String(localized: "driver.status.nearby_detail.clear")
            )
        }
        return CPInformationItem(
            title: String(localized: "driver.status.nearby_prefix") + " " + nearbyNamesTitle(nearby),
            detail: String(format: String(localized: "driver.nearby"), nearby.count)
        )
    }

    private func locationDeniedItem() -> CPInformationItem {
        CPInformationItem(
            title: NSLocalizedString("location.access.denied.carplay", comment: ""),
            detail: nil
        )
    }
}
