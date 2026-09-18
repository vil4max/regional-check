import DriveCheckKit
import Foundation
import SwiftUI
import UIKit

/// Compact Home-screen card with the upstream raster alert map.
///
/// The picture is loaded on appear and on explicit refresh only. Statuses,
/// age honesty, and VoiceOver semantics come from the ViewModel: the card
/// shows the image fetch time (never the snapshot `checkedAt`), and the
/// accessibility label is generated from the shared JSON snapshot.
struct MapCardView: View {
    var viewModel: MapViewModel

    @Environment(\.colorScheme) private var colorScheme

    private static let cardHeight: CGFloat = 200

    var body: some View {
        content
            .frame(height: Self.cardHeight)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.md)
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

    @ViewBuilder
    private var content: some View {
        if let uiImage = decodedImage {
            VStack(spacing: Theme.Spacing.sm) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel(Text(viewModel.accessibilityLabel))

                footer
            }
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

    private var footer: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let age = viewModel.ageText {
                Text(age)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            refreshButton
        }
    }

    private var refreshButton: some View {
        Button(action: viewModel.refresh) {
            if viewModel.isLoading {
                ProgressView()
                    .tint(Theme.Colors.onFillSecondary)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(Theme.Typography.refreshSymbol)
                    .foregroundStyle(Theme.Colors.onFillSecondary)
            }
        }
        .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
        .disabled(viewModel.isLoading)
        .accessibilityLabel(Text("Refresh"))
    }

    private var decodedImage: UIImage? {
        viewModel.imageData.flatMap(UIImage.init(data:))
    }

    private func variant(for scheme: ColorScheme) -> MapImageVariant {
        scheme == .dark ? .night : .day
    }
}

#if DEBUG
    #Preview("Map card loaded") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network)
        return ZStack {
            Theme.Colors.dashboard.ignoresSafeArea()
            MapCardView(viewModel: .preloaded(
                imageData: FixtureNetwork.previewMapImage,
                loadedAt: AppContainer.fixtureNow,
                statusSource: container.status,
                httpClient: network,
                variant: .night
            ))
        }
    }
#endif
