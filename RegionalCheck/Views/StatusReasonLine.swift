import DriveCheckKit
import SwiftUI

/// STATUS-reason: the hero's one line saying why the status is what it is. While the region is
/// quiet it names the neighbours under alert (REQ-SURF-005), which is the whole reason for a yellow
/// "Stay Alert"; during the region's own alert it gives the alert's start from the response
/// (REQ-SURF-014) instead. Gated on the phase, not the accent, so stale data keeps the line: the
/// meta line right under it states the data's age.
enum StatusReasonLine {
    @MainActor
    static func text(
        region: AlertRegion,
        phase: StatusState.Phase,
        snapshot: AlertsSnapshot?,
        alarmStartedAt: Date?,
        checkedAt: Date?
    ) -> String? {
        guard snapshot != nil else { return nil }
        switch phase {
        case .quiet:
            let nearby = NearbyAlertsLine.regions(near: region, snapshot: snapshot)
            guard !nearby.isEmpty else { return nil }
            return String(format: String(localized: "status.reason.nearby"), NearbyAlertsLine.names(nearby))
        case .alarm:
            guard let alarmStartedAt else { return nil }
            let time = DayAwareTime.text(alarmStartedAt, reference: checkedAt ?? alarmStartedAt)
            return String(format: String(localized: "status.reason.since"), time)
        case .idle, .error, .regionUnavailable:
            return nil
        }
    }
}

/// STATUS-reason AC-4: the way to the region list while no map is shown to tap. The map is the
/// count, so the row carries none; it is one plain grouped row with a chevron, like Settings.
struct StatusRegionListRow: View {
    let onOpenRegionList: () -> Void

    static func isShown(mapIsShown: Bool) -> Bool {
        !mapIsShown
    }

    var body: some View {
        Button(action: onOpenRegionList) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("status.regions.title")
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textSecondary.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .font(Theme.RedesignTypography.body)
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
            .frame(minHeight: Theme.RedesignRowSizes.grouped)
            .contentShape(Rectangle())
        }
        .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .background(
            Theme.RedesignColors.surface,
            in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
        )
    }
}
