import DriveCheckKit
import SwiftUI

/// REQ-SURF-005 on the phone Status tab: the names of the neighbouring regions under alert, the
/// value of a plain "Nearby" row (UI-simplify AC-2). It is computed from `NearbyRegionPolicy` and
/// the snapshot directly rather than taken from a summary, and it is not withheld for stale data:
/// the hero's meta line already states the data's age right above it. The names are the CarPlay
/// Status row's (`NearbyAlertsLine`); only a known quiet or alarm status is qualified by them.
enum StatusNearbyLine {
    @MainActor
    static func names(region: AlertRegion, phase: StatusState.Phase, snapshot: AlertsSnapshot?) -> String? {
        guard phase == .quiet || phase == .alarm else { return nil }
        let nearby = NearbyAlertsLine.regions(near: region, snapshot: snapshot)
        return nearby.isEmpty ? nil : NearbyAlertsLine.names(nearby)
    }
}

/// UI-simplify AC-3: "N of 25", the value of the row that opens the region list. It replaces the
/// map's caption, so it counts the same snapshot the caption counted.
enum StatusRegionsCount {
    static func text(snapshot: AlertsSnapshot?) -> String? {
        guard let snapshot else { return nil }
        let alarms = AlertRegion.allCases.filter { snapshot.status(for: $0) == .alarm }.count
        return String(format: String(localized: "status.regions.count"), alarms, AlertRegion.allCases.count)
    }
}

/// The rows under the hero, in one inset-grouped card like a Settings section: "Nearby" when a
/// neighbour is under alert, and "Regions under alert" when there is a snapshot to count and a
/// list to open. No glyphs and no warning colour (owner, 2026-11-10: calm, built-in look).
struct StatusOverviewRows: View {
    let nearbyNames: String?
    let regionsCount: String?
    var onOpenRegionList: (() -> Void)?

    private var showsRegionsRow: Bool {
        regionsCount != nil && onOpenRegionList != nil
    }

    var body: some View {
        if nearbyNames != nil || showsRegionsRow {
            VStack(spacing: 0) {
                if let nearbyNames {
                    row(title: "status.nearby.title", value: nearbyNames)
                        .accessibilityElement(children: .combine)
                }
                if nearbyNames != nil, showsRegionsRow {
                    Divider()
                        .overlay(Theme.RedesignColors.separator)
                        .padding(.leading, Theme.RedesignCardSizes.paddingHorizontal)
                }
                if let regionsCount, let onOpenRegionList {
                    Button(action: onOpenRegionList) {
                        row(title: "status.regions.title", value: regionsCount, showsChevron: true)
                    }
                    .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.button))
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }
            }
            .background(
                Theme.RedesignColors.surface,
                in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
            )
        }
    }

    private func row(title: LocalizedStringKey, value: String, showsChevron: Bool = false) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .foregroundStyle(Theme.RedesignColors.textPrimary)
            Spacer(minLength: Theme.Spacing.sm)
            Text(value)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .multilineTextAlignment(.trailing)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textSecondary.opacity(0.6))
                    .accessibilityHidden(true)
            }
        }
        .font(Theme.RedesignTypography.body)
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .frame(minHeight: Theme.RedesignRowSizes.grouped)
        .contentShape(Rectangle())
    }
}
