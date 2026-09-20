import DriveCheckKit
import SwiftUI

struct RegionsView: View {
    var viewModel: RegionsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.RedesignSpacing.screenInset) {
                    currentRegionCard
                    listContent
                }
                .padding(.horizontal, Theme.RedesignSpacing.screenInset)
                .padding(.top, Theme.RedesignSpacing.screenInset)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.RedesignColors.background)
            .navigationTitle("tab.regions")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: searchTextBinding,
                isPresented: searchActiveBinding,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text("regions.search.placeholder")
            )
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var listContent: some View {
        if viewModel.showsNoSearchResults {
            noResultsState
        } else if viewModel.isLoading, !viewModel.isSearchActive {
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
        // "ALERT ACTIVE · N" (iphone-regions.png): the localized label plus a plain count suffix,
        // rather than a new format-string key for a single middot-separated number. Concatenate
        // before `.textCase` — `Text.textCase(_:)` returns `some View`, not `Text`, so it can't
        // be an operand of `Text`'s `+`.
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

    private var noResultsState: some View {
        VStack(spacing: Theme.RedesignSpacing.screenInset / 2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Theme.RedesignColors.textTertiary)
            Text("regions.search.empty")
                .font(Theme.RedesignTypography.regionName)
                .foregroundStyle(Theme.RedesignColors.textPrimary)
            Text("regions.search.empty_hint")
                .font(Theme.RedesignTypography.caption)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Current region card

    private var currentRegionCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.RedesignCardSizes.innerGap) {
                currentRegionIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text("regions.current")
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                    Text(viewModel.selectedRegion.title)
                        .font(Theme.RedesignTypography.regionName)
                        .foregroundStyle(Theme.RedesignColors.textPrimary)
                }
                Spacer(minLength: Theme.RedesignCardSizes.innerGap)
                statusPill(for: viewModel.status(for: viewModel.selectedRegion))
            }
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
            .padding(.vertical, Theme.RedesignCardSizes.paddingVertical)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.accessibilityLabel(for: viewModel.selectedRegion))

            Divider().overlay(Theme.RedesignColors.separator)

            Toggle(isOn: followsLocationBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("regions.follow_location")
                        .font(Theme.RedesignTypography.body)
                        .foregroundStyle(Theme.RedesignColors.textPrimary)
                    Text("regions.follow_location.subtitle")
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.textSecondary)
                }
            }
            .tint(Theme.RedesignColors.statusClear)
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
            .padding(.vertical, Theme.RedesignCardSizes.paddingVertical)
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

    private var currentRegionIcon: some View {
        let accent = RegionStatusPresentation.accent(for: viewModel.status(for: viewModel.selectedRegion))
        let color = Theme.RedesignColors.statusAccent(for: accent)
        return Image(systemName: "location.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .background(Theme.RedesignColors.tints(for: color).soft, in: Circle())
    }
}

// MARK: - Region sections

/// A separate `extension` block, not more of `RegionsView`'s own body: SwiftLint's
/// `type_body_length` counts each type declaration independently, and the primary struct above
/// is already at the limit once search added the region-section and row rendering.
private extension RegionsView {
    func regionSection(
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
        let isSelected = region == viewModel.selectedRegion
        return Button {
            viewModel.pin(region)
        } label: {
            HStack(spacing: Theme.RedesignCardSizes.innerGap) {
                statusDot(for: status)
                Text(region.title)
                    .font(Theme.RedesignTypography.body)
                    .foregroundStyle(isSelected ? Theme.RedesignColors.textSecondary : Theme.RedesignColors.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.RedesignColors.proAccent)
                } else if status == .alarm {
                    Text("Alert Active")
                        .font(Theme.RedesignTypography.caption)
                        .foregroundStyle(Theme.RedesignColors.statusAlert)
                } else if status == nil {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(minHeight: status == .alarm ? Theme.RedesignRowSizes.alertRegionList : Theme.RedesignRowSizes
                .regionList)
            .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.accessibilityLabel(for: region))
        .contextMenu {
            if viewModel.canPinSecondaryRegion {
                Button("regions.pin_secondary") {
                    viewModel.pinSecondaryRegion(region)
                }
            }
        }
    }

    private func statusDot(for status: AlertStatus?) -> some View {
        let color = Theme.RedesignColors.statusAccent(for: RegionStatusPresentation.accent(for: status))
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    @ViewBuilder
    func statusPill(for status: AlertStatus?) -> some View {
        let accentValue = RegionStatusPresentation.accent(for: status)
        let color = Theme.RedesignColors.statusAccent(for: accentValue)
        Group {
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

    // MARK: - Bindings

    var followsLocationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.followsLocation },
            set: viewModel.setFollowsLocation
        )
    }

    var searchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { viewModel.searchText = $0 }
        )
    }

    var searchActiveBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isSearchActive },
            set: viewModel.setSearchActive
        )
    }
}

/// Maps a region's `AlertStatus?` to the redesign's status accent (5.1: alarm → alert, quiet →
/// clear, unresolved → checking). Kept outside `RegionsView` — a free helper, not a view method —
/// to stay under `Tooling/.swiftlint.yml`'s `type_body_length` for the view struct.
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
    #Preview("Regions") {
        RegionsView(viewModel: AppContainer.fixture().regionsViewModel)
    }

    #Preview("Regions search results") {
        let container = AppContainer.fixture()
        container.regionsViewModel.isSearchActive = true
        container.regionsViewModel.searchText = "Kyiv"
        return RegionsView(viewModel: container.regionsViewModel)
    }

    #Preview("Regions search empty") {
        let container = AppContainer.fixture()
        container.regionsViewModel.isSearchActive = true
        container.regionsViewModel.searchText = "Zzz"
        return RegionsView(viewModel: container.regionsViewModel)
    }

    #Preview("Regions AX5") {
        RegionsView(viewModel: AppContainer.fixture().regionsViewModel)
            .dynamicTypeSize(.accessibility5)
    }
#endif
