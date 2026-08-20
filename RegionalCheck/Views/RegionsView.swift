import DriveCheckKit
import SwiftUI

struct RegionsView: View {
    var viewModel: RegionsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    currentRegionRow
                    Toggle(isOn: followsLocationBinding) {
                        Text("regions.follow_location")
                            .foregroundStyle(Theme.Colors.onFill)
                    }
                    .tint(Theme.Colors.onboarding)
                    .listRowBackground(Theme.Colors.dashboard.opacity(0.92))
                }

                if viewModel.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Theme.Colors.dashboard.opacity(0.92))
                    }
                } else {
                    if !viewModel.alarmRegions.isEmpty {
                        Section("regions.section.alarm") {
                            ForEach(viewModel.alarmRegions, id: \.self) { region in
                                regionRow(region)
                            }
                        }
                    }

                    Section("regions.section.other") {
                        ForEach(viewModel.otherRegions, id: \.self) { region in
                            regionRow(region)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.dashboard)
            .navigationTitle(Text("tab.regions"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.Colors.dashboard, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var currentRegionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm / 2) {
                Text("regions.current")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                Text(viewModel.selectedRegion.title)
                    .font(Theme.Typography.regionTitle)
                    .foregroundStyle(Theme.Colors.onFill)
            }
            Spacer()
            statusLabel(for: viewModel.selectedRegion)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.accessibilityLabel(for: viewModel.selectedRegion))
        .listRowBackground(Theme.Colors.dashboard.opacity(0.92))
    }

    private func regionRow(_ region: AlertRegion) -> some View {
        Button {
            viewModel.pin(region)
        } label: {
            HStack {
                Text(region.title)
                    .foregroundStyle(Theme.Colors.onFill)
                Spacer()
                if region == viewModel.selectedRegion {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.Colors.onboarding)
                }
                statusLabel(for: region)
            }
        }
        .accessibilityLabel(viewModel.accessibilityLabel(for: region))
        .listRowBackground(Theme.Colors.dashboard.opacity(0.92))
        .contextMenu {
            if viewModel.canPinSecondaryRegion {
                Button("regions.pin_secondary") {
                    viewModel.pinSecondaryRegion(region)
                }
            }
        }
    }

    @ViewBuilder
    private func statusLabel(for region: AlertRegion) -> some View {
        switch viewModel.status(for: region) {
        case .alarm:
            Text("Alert Active")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.attention)
        case .quiet:
            Text("All Clear")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.normal)
        case nil:
            ProgressView()
                .controlSize(.small)
        }
    }

    private var followsLocationBinding: Binding<Bool> {
        Binding(
            get: { viewModel.followsLocation },
            set: viewModel.setFollowsLocation
        )
    }
}

#Preview {
    RegionsView(
        viewModel: AppContainer().regionsViewModel
    )
}
