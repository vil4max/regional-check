import DriveCheckKit
import SwiftUI

/// REQ-SURF-005 on the phone Status tab: one compact line naming the neighbouring regions under
/// alert. It is computed from `NearbyRegionPolicy` and the snapshot directly rather than taken
/// from the summary, so it stays on Status now that the summary lives on Details, and it is not
/// withheld when the summary withholds its claims for stale data — the hero's meta line already
/// states the data's age right above it. The wording is the CarPlay Status row's.
enum StatusNearbyLine {
    @MainActor
    static func text(region: AlertRegion, phase: StatusState.Phase, snapshot: AlertsSnapshot?) -> String? {
        guard phase == .quiet || phase == .alarm, let snapshot else { return nil }
        let alerts = AlertRegion.allCases.filter { snapshot.status(for: $0) == .alarm }
        let nearby = NearbyRegionPolicy.activeAlerts(near: region, among: alerts)
        guard !nearby.isEmpty else { return nil }
        return String(localized: "driver.status.nearby_prefix") + " " + nearbyNamesTitle(nearby)
    }
}

struct StatusNearbyLineView: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.RedesignCardSizes.innerGap) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.RedesignColors.statusStale)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.RedesignTypography.body.weight(.semibold))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .padding(.vertical, Theme.RedesignCardSizes.innerGap)
        .background(
            Theme.RedesignColors.surface,
            in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
