import DriveCheckKit
import SwiftUI

/// The region list pushed from the Status tab's map (ADR 0015). Read-only by construction: rows
/// are plain content, not buttons, and `RegionListViewModel` has no way to change the region —
/// it follows location only (owner, 2026-09-20). Pushed inside the Status tab's own
/// `NavigationStack`, so it has the system back button and keeps the tab bar.
struct RegionListView: View {
    var viewModel: RegionListViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.RedesignSpacing.screenInset) {
                currentRegionCard
                listContent
            }
            .padding(.horizontal, Theme.RedesignSpacing.screenInset)
            .padding(.vertical, Theme.RedesignSpacing.screenInset)
        }
        .background(Theme.RedesignColors.background)
        .navigationTitle("regions.list.title")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isLoading {
            loadingState
        } else {
            if !viewModel.alarmRegions.isEmpty {
                regionSection(
                    regions: viewModel.alarmRegions,
                    fill: Theme.RedesignColors.alertGroupFill,
                    stroke: Theme.RedesignColors.alertGroupStroke,
                    header: { alarmSectionHeader }
                )
            }
            regionSection(
                regions: viewModel.otherRegions,
                fill: Theme.RedesignColors.surface,
                stroke: Theme.RedesignColors.surfaceStroke,
                header: { Text("regions.section.other").textCase(.uppercase) }
            )
        }
    }

    private var alarmSectionHeader: some View {
        // Concatenate before `.textCase`: `Text.textCase(_:)` returns `some View`, not `Text`, so
        // it cannot be an operand of `Text`'s `+`.
        (Text("regions.section.alarm") + Text(" · \(viewModel.alarmRegions.count)")).textCase(.uppercase)
    }

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, Theme.RedesignSpacing.screenInset)
    }

    // MARK: - Current region card

    private var currentRegionCard: some View {
        // Side by side, the icon and the pill leave an accessibility-size region name a column a
        // few characters wide, which breaks it mid-word; stacked, it gets the card's full width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap))
            : AnyLayout(HStackLayout(spacing: Theme.RedesignCardSizes.innerGap))
        return layout {
            currentRegionIcon
            VStack(alignment: .leading, spacing: 2) {
                Text("regions.current")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
                Text(viewModel.currentRegion.title)
                    .font(Theme.RedesignTypography.regionName)
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: Theme.RedesignCardSizes.innerGap)
            }
            statusPill(for: viewModel.status(for: viewModel.currentRegion))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .padding(.vertical, Theme.RedesignCardSizes.paddingVertical)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.accessibilityLabel(for: viewModel.currentRegion))
        .background(
            Theme.RedesignColors.surface,
            in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                .strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1)
        )
    }

    private var currentRegionIcon: some View {
        let accent = RegionStatusPresentation.accent(for: viewModel.status(for: viewModel.currentRegion))
        let color = Theme.RedesignColors.statusAccent(for: accent)
        return Image(systemName: "location.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .background(Theme.RedesignColors.tints(for: color).soft, in: Circle())
    }

    // MARK: - Region sections

    private func regionSection(
        regions: [AlertRegion],
        fill: Color,
        stroke: Color,
        @ViewBuilder header: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.RedesignCardSizes.innerGap) {
            header()
                .font(Theme.RedesignTypography.sectionHeader)
                .tracking(Theme.RedesignTypography.sectionHeaderTracking)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(regions.enumerated()), id: \.element) { index, region in
                    regionRow(region)
                    if index < regions.count - 1 {
                        Divider().overlay(Theme.RedesignColors.separator)
                    }
                }
            }
            .background(
                fill,
                in: RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
        }
    }

    private func regionRow(_ region: AlertRegion) -> some View {
        let status = viewModel.status(for: region)
        let isAlarm = status == .alarm
        return HStack(spacing: Theme.RedesignCardSizes.innerGap) {
            statusDot(for: status)
            Text(region.title)
                .font(Theme.RedesignTypography.body)
                .foregroundStyle(Theme.RedesignColors.textPrimary)
            Spacer()
            // A location glyph, not a checkmark: a checkmark reads as "selected in this list",
            // and nothing in this list can be selected.
            if region == viewModel.currentRegion {
                Image(systemName: "location.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.RedesignColors.textSecondary)
            }
            if isAlarm {
                Text("Alert Active")
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.statusAlert)
            } else if status == nil {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(minHeight: isAlarm ? Theme.RedesignRowSizes.alertRegionList : Theme.RedesignRowSizes.regionList)
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.accessibilityLabel(for: region))
    }

    private func statusDot(for status: AlertStatus?) -> some View {
        let color = Theme.RedesignColors.statusAccent(for: RegionStatusPresentation.accent(for: status))
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private func statusPill(for status: AlertStatus?) -> some View {
        let color = Theme.RedesignColors.statusAccent(for: RegionStatusPresentation.accent(for: status))
        return Group {
            switch status {
            case .alarm:
                Text("Alert Active")
            case .quiet:
                Text("All Clear")
            case nil:
                ProgressView().controlSize(.small)
            }
        }
        .font(Theme.RedesignTypography.caption.weight(.semibold))
        .foregroundStyle(color)
        .multilineTextAlignment(.center)
        // Let the pill grow to contain wrapped accessibility text.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.RedesignColors.tints(for: color).soft, in: Capsule())
    }
}

/// Maps a region's `AlertStatus?` to the redesign's status accent (alarm → alert, quiet → clear,
/// unresolved → checking).
private enum RegionStatusPresentation {
    static func accent(for status: AlertStatus?) -> Theme.RedesignStatusAccent {
        switch status {
        case .alarm: .alert
        case .quiet: .clear
        case nil: .checking
        }
    }
}

#if DEBUG
    // Inside a `NavigationStack`, as the list is only ever shown pushed: without one the large
    // title and its safe area are absent and the baseline would describe a screen nobody sees.
    #Preview("Region list") {
        NavigationStack {
            RegionListView(viewModel: AppContainer.fixture().regionListViewModel)
        }
    }

    #Preview("Region list AX5") {
        NavigationStack {
            RegionListView(viewModel: AppContainer.fixture(region: .kharkiv).regionListViewModel)
        }
        .dynamicTypeSize(.accessibility5)
    }
#endif
