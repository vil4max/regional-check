import DriveCheckKit
import Foundation
import SwiftUI
import UIKit

/// Phone-only tab with the upstream raster alert map.
///
/// The picture is loaded on appear and on explicit refresh only. Statuses,
/// age honesty, and VoiceOver semantics come from the ViewModel: the tab
/// shows the image fetch time (never the snapshot `checkedAt`), and the
/// accessibility label is generated from the shared JSON snapshot.
struct MapView: View {
    var viewModel: MapViewModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            content
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.dashboard)
                .navigationTitle(Text("tab.map"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Theme.Colors.dashboard, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .onAppear {
                    viewModel.setVariant(variant(for: colorScheme))
                    viewModel.appear()
                }
                .onChange(of: colorScheme) { _, newScheme in
                    viewModel.setVariant(variant(for: newScheme))
                }
                .onDisappear {
                    viewModel.disappear()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let uiImage = decodedImage {
            VStack(spacing: Theme.Spacing.md) {
                Spacer(minLength: 0)
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(Text(viewModel.accessibilityLabel))
                if let age = viewModel.ageText {
                    Text(age)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.onFillSecondary)
                }
                if viewModel.loadFailed {
                    errorRow
                }
                StatusRefreshButtonView(
                    isLoading: viewModel.isLoading,
                    onRefresh: viewModel.refresh
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.md)
        } else if viewModel.isLoading {
            ProgressView()
                .tint(Theme.Colors.onFill)
        } else if viewModel.loadFailed {
            VStack(spacing: Theme.Spacing.sm) {
                Text("map.error")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
                Button("status.explanation.retry", action: viewModel.refresh)
                    .font(Theme.Typography.refreshLabel)
                    .foregroundStyle(Theme.Colors.onboarding)
            }
            .padding(.horizontal, Theme.Spacing.xl)
        } else {
            ProgressView()
                .tint(Theme.Colors.onFill)
        }
    }

    private var errorRow: some View {
        VStack(spacing: Theme.Spacing.sm / 2) {
            Text("map.error")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.onFillSecondary)
            Button("status.explanation.retry", action: viewModel.refresh)
                .font(Theme.Typography.refreshLabel)
                .foregroundStyle(Theme.Colors.onboarding)
        }
    }

    private var decodedImage: UIImage? {
        viewModel.imageData.flatMap(UIImage.init(data:))
    }

    private func variant(for scheme: ColorScheme) -> MapImageVariant {
        scheme == .dark ? .night : .day
    }
}

#if DEBUG
    #Preview {
        MapView(viewModel: MapViewModel(
            statusSource: MapPreviewStatusSource(),
            httpClient: MapPreviewFailingClient()
        ))
    }

    private final class MapPreviewStatusSource: RegionStatusSource {
        var lastSnapshot: AlertsSnapshot? {
            AlertsSnapshot(
                source: "preview",
                serverCachedAt: nil,
                fetchedAt: Date(),
                statuses: Dictionary(
                    uniqueKeysWithValues: AlertRegion.allCases.map { ($0, .quiet) }
                )
            )
        }
    }

    private struct MapPreviewFailingClient: HTTPClient, Sendable {
        func data(for _: URLRequest) async throws -> (Data, URLResponse) {
            throw URLError(.notConnectedToInternet)
        }
    }
#endif
