import DriveCheckKit
import SwiftUI

/// The Status tab's grouped list (`docs/tasks/redesign.md` §6.1 item 4): "Also watching" (with a
/// secondary region only) and the location-access-denied row. The map is no longer a row here;
/// it is the inline `AlertMapCard` under the hero (ADR 0015).
struct StatusGroupedListCard: View {
    let secondaryRegion: AlertRegion?
    let secondaryStatus: AlertStatus?
    let showsLocationAccessDenied: Bool
    let onOpenLocationSettings: (() -> Void)?

    var body: some View {
        if hasAnyRow {
            VStack(spacing: 0) {
                if let secondaryRegion {
                    alsoWatchingRow(region: secondaryRegion, status: secondaryStatus)
                    if showsLocationAccessDenied {
                        rowDivider
                    }
                }
                if showsLocationAccessDenied {
                    locationDeniedRow
                }
            }
            .background(
                Theme.RedesignColors.surface,
                in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                    .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
            )
        }
    }

    private var hasAnyRow: Bool {
        secondaryRegion != nil || showsLocationAccessDenied
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.RedesignColors.separator)
            .frame(height: 1)
            .padding(.leading, Theme.RedesignCardSizes.paddingHorizontal)
    }

    private func alsoWatchingRow(region: AlertRegion, status: AlertStatus?) -> some View {
        HStack(spacing: Theme.RedesignCardSizes.innerGap) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(Theme.RedesignColors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Also watching")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                Text(region.title)
                    .font(Theme.RedesignTypography.body.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
            }

            Spacer(minLength: Theme.RedesignCardSizes.innerGap)

            statusPill(for: status)
        }
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .frame(minHeight: Theme.RedesignRowSizes.grouped)
        .accessibilityElement(children: .combine)
    }

    private func statusPill(for status: AlertStatus?) -> some View {
        let (color, text): (Color, String) = switch status {
        case .alarm: (Theme.RedesignColors.statusAlert, String(localized: "Alert Active"))
        case .quiet: (Theme.RedesignColors.statusClear, String(localized: "All Clear"))
        case nil: (Theme.RedesignColors.statusChecking, String(localized: "Unavailable"))
        }
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(Theme.RedesignTypography.caption.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private var locationDeniedRow: some View {
        HStack(alignment: .top, spacing: Theme.RedesignCardSizes.innerGap) {
            Image(systemName: "location.slash")
                .foregroundStyle(Theme.RedesignColors.statusStale)

            VStack(alignment: .leading, spacing: 2) {
                Text("location.access.denied")
                    .font(Theme.RedesignTypography.body.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                Text("location.access.enable_tip")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
            }

            Spacer(minLength: Theme.RedesignCardSizes.innerGap)

            if let onOpenLocationSettings {
                Button("location.access.open_settings", action: onOpenLocationSettings)
                    .font(Theme.RedesignTypography.caption.weight(.semibold))
                    .foregroundStyle(Theme.RedesignColors.statusStale)
            }
        }
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .padding(.vertical, Theme.RedesignCardSizes.innerGap)
        .accessibilityElement(children: .combine)
    }
}
