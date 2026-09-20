import DriveCheckKit
import SwiftUI
import UIKit

/// The inline alert map on the Status tab (ADR 0015). It loads once per session on its own
/// appear, after the status request, and again only from "Refresh map" in the failed state —
/// never by polling and never from pull to refresh (REQ-REFRESH-001, REQ-PROVIDER-002).
///
/// Loading, loaded and failed all fill one box whose shape comes from
/// `MapImageSource.aspectRatio`, so the Status tab does not reflow when the image lands. A
/// failure never shows a previous image: a stale picture presented as current is the failure
/// mode to avoid, so `content` has no branch that falls back to `imageData` while `loadFailed`.
///
/// The whole card is one tap target that opens the region list (ADR 0015). Per-region
/// hit-testing is not possible: the upstream raster has no region semantics. The tap is a gesture
/// on the card rather than a `Button` around it because the failed state holds its own
/// "Refresh map" button, which must keep winning the touch inside its bounds; a failed map must
/// not make the list unreachable either, so the rest of the card still opens it.
struct AlertMapCard: View {
    let viewModel: MapViewModel
    /// `nil` renders the card inert, with no button trait — a preview or a host with no list.
    var onOpenRegionList: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
    }

    var body: some View {
        Theme.RedesignColors.surface
            .aspectRatio(MapImageSource.aspectRatio, contentMode: .fit)
            .overlay { content }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1))
            .contentShape(shape)
            .onTapGesture {
                onOpenRegionList?()
            }
            .onAppear {
                viewModel.setVariant(variant(for: colorScheme))
                // A preview frozen in its loading or failed state would race this real load and
                // could be captured as loaded (`HostProcess.isUnitTesting`, app-wide convention).
                if !HostProcess.isUnitTesting {
                    viewModel.appear()
                }
            }
            .onChange(of: colorScheme) { _, newScheme in
                viewModel.setVariant(variant(for: newScheme))
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.loadFailed {
            failedState
        } else if let uiImage = viewModel.imageData.flatMap(UIImage.init(data:)) {
            loadedState(uiImage)
        } else {
            loadingState
        }
    }

    private func loadedState(_ uiImage: UIImage) -> some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Text(viewModel.accessibilityLabel))
                .opensRegionList(onOpenRegionList)

            if let caption = viewModel.fullscreenCaption {
                Text(caption)
                    .font(Theme.RedesignTypography.caption)
                    .foregroundStyle(Theme.RedesignColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
                    .padding(.vertical, Theme.Spacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [
                                Theme.RedesignColors.background.opacity(0),
                                Theme.RedesignColors.background.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ProgressView()
                .tint(Theme.RedesignColors.textSecondary)
            Text("map.fullscreen.loading")
                .font(Theme.RedesignTypography.body)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .opensRegionList(onOpenRegionList)
    }

    private var failedState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(Theme.RedesignColors.textSecondary)
                .accessibilityHidden(true)
            Text("map.error")
                .font(Theme.RedesignTypography.body.weight(.semibold))
                .foregroundStyle(Theme.RedesignColors.textPrimary)
                .opensRegionList(onOpenRegionList)
            Button("map.fullscreen.refresh") {
                viewModel.refresh()
            }
            .font(Theme.RedesignTypography.caption.weight(.semibold))
            .foregroundStyle(Theme.RedesignColors.statusStale)
            .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Theme.RedesignCardSizes.paddingHorizontal)
    }

    private func variant(for scheme: ColorScheme) -> MapImageVariant {
        scheme == .dark ? .night : .day
    }
}

private extension View {
    /// VoiceOver's side of the card-wide tap: the gesture itself is invisible to it, so the one
    /// element each state always has announces as a button, carries the hint, and opens the list
    /// on activation. "Refresh map" stays a separate element with its own action.
    @ViewBuilder
    func opensRegionList(_ action: (() -> Void)?) -> some View {
        if let action {
            accessibilityAddTraits(.isButton)
                .accessibilityHint(Text("map.card.open_regions_hint"))
                .accessibilityAction(.default, action)
        } else {
            self
        }
    }
}

#if DEBUG
    /// Not private: Prefire copies each preview body into the test target, which must see it.
    struct AlertMapCardPreviewHost: View {
        let viewModel: MapViewModel

        var body: some View {
            VStack {
                AlertMapCard(viewModel: viewModel)
                Spacer()
            }
            .padding(Theme.RedesignSpacing.screenInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.RedesignColors.background)
        }
    }

    #Preview("Map card loaded") {
        let network = FixtureNetwork(alarmRegions: [.kharkiv, .sumy])
        let container = AppContainer.fixture(network: network)
        AlertMapCardPreviewHost(viewModel: .preloaded(
            imageData: FixtureNetwork.previewMapImage,
            loadedAt: AppContainer.fixtureNow,
            statusSource: container.status,
            httpClient: network,
            variant: .night
        ))
    }

    #Preview("Map card loading") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network)
        AlertMapCardPreviewHost(viewModel: .loadingPreview(statusSource: container.status, httpClient: network))
    }

    #Preview("Map card failed") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network)
        AlertMapCardPreviewHost(viewModel: .failedPreview(statusSource: container.status, httpClient: network))
    }
#endif
