import CarPlay
import DriveCheckKit

/// Builds CarPlay's only screen, Status (REQ-SURF-006), from `CarPlayLoadState` plus shared
/// region and location state. Keeps template construction out of the scene delegate so the
/// delegate can focus on lifecycle and observation.
@MainActor
struct CarPlayTemplateBuilder {
    private let status: any CarPlayStatusReading
    private let regions: any CarPlayRegionReading
    private let location: any CarPlayLocationSource
    private let onRefresh: () -> Void

    init(
        status: any CarPlayStatusReading,
        regions: any CarPlayRegionReading,
        location: any CarPlayLocationSource,
        onRefresh: @escaping () -> Void
    ) {
        self.status = status
        self.regions = regions
        self.location = location
        self.onRefresh = onRefresh
    }

    /// REQ-SURF-001: the short status form in the title (marker + one or two words, read at a
    /// glance); no marker when the shown status is not fresh (REQ-REFRESH-007). REQ-SURF-006: the
    /// rows are the region (with its age only when the data is not fresh) and, only when there is
    /// something to say, nearby alerts (REQ-SURF-005) or blocked location access; nothing else
    /// competes with the status for the driver's glance.
    func rootTemplate(loadState: CarPlayLoadState, freshness: CarPlayFreshness) -> CPInformationTemplate {
        let snapshot = loadState.snapshot
        let freshSnapshot = snapshot.flatMap { freshness.isFresh($0) ? $0 : nil }
        let items: [CPInformationItem] =
            if let freshSnapshot {
                freshRows(freshSnapshot)
            } else {
                staleRows(cached: snapshot, now: freshness.now)
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
            return "\(CarPlayHeadline.marker(for: freshSnapshot.state)) \(freshSnapshot.state.title)"
        }
        if loadState.isLoading {
            return String(localized: "driver.updating")
        }
        return String(localized: "driver.status.no_current_data.title")
    }

    private func freshRows(_ snapshot: CarPlaySnapshot) -> [CPInformationItem] {
        // The title's marker already says the data is fresh, so the time adds only letters.
        var items = [CPInformationItem(title: status.regionTitle, detail: freshDetail())]
        if location.isAuthorizationBlocked {
            items.append(locationDeniedItem())
        } else if let nearby = nearbyItem() {
            items.append(nearby)
        }
        return items
    }

    /// Region and age only: the title already says "no current data", and the cached status
    /// is not shown as a row because a stale status must not be read as current.
    private func staleRows(cached: CarPlaySnapshot?, now: Date) -> [CPInformationItem] {
        var items = [
            CPInformationItem(title: status.regionTitle, detail: staleDetail(updated: cached?.checkedAt, now: now))
        ]
        if location.isAuthorizationBlocked {
            items.append(locationDeniedItem())
        }
        return items
    }

    /// Only the outside-Ukraine note: it changes what the driver can trust.
    private func freshDetail() -> String? {
        regions.isOutsideUkraine ? String(localized: "driver.region.outside") : nil
    }

    /// `updated` is `nil` only when nothing has ever been fetched; the detail is then empty. A
    /// status from an earlier day carries its date, so "Last update 14:32" never reads as today.
    private func staleDetail(updated: Date?, now: Date) -> String {
        if regions.isOutsideUkraine {
            return String(localized: "driver.region.outside")
        }
        guard let updated else { return "" }
        let sameDay = Calendar.current.isDate(updated, inSameDayAs: now)
        let time =
            sameDay
            ? updated.formatted(date: .omitted, time: .shortened)
            : updated.formatted(date: .abbreviated, time: .shortened)
        return String(format: String(localized: "driver.status.last_update"), time)
    }

    /// `nil` when no neighbour is under alert: an empty "Nothing nearby" row is text the driver
    /// does not need (REQ-SURF-005).
    private func nearbyItem() -> CPInformationItem? {
        NearbyAlertsLine.text(region: status.currentRegion, snapshot: status.lastSnapshot)
            .map { CPInformationItem(title: $0, detail: nil) }
    }

    private func locationDeniedItem() -> CPInformationItem {
        CPInformationItem(title: String(localized: "location.access.denied.carplay"), detail: nil)
    }
}
