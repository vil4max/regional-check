import DriveCheckKit
import SwiftUI
import UIKit

/// The inline alert map on the Status tab (ADR 0015). It loads once per phone foreground session,
/// on its own appear or when the scene returns to the foreground with the card on screen, after the
/// status request, and again only when a pull to refresh finds it failed — never by polling, and a
/// loaded map is never re-requested by the pull (REQ-REFRESH-001, REQ-PROVIDER-002).
///
/// Loading and loaded fill one box whose shape comes from `MapImageSource.aspectRatio`, so the
/// Status tab does not reflow when the image lands. A failed map is hidden, with no error text or
/// button (UI-simplify AC-4): the "Regions under alert" row still opens the list. A failure never
/// shows a previous image: a stale picture presented as current is the failure mode to avoid.
///
/// The whole card is one tap target that opens the region list (ADR 0015). Per-region
/// hit-testing is not possible: the upstream raster has no region semantics.
struct AlertMapCard: View {
    let viewModel: MapViewModel
    /// `nil` renders the card inert, with no button trait — a preview or a host with no list.
    var onOpenRegionList: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    /// Counts taps that open the list, so each one plays the press haptic.
    @State private var openCount = 0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RedesignCardSizes.groupedRadius, style: .continuous)
    }

    var body: some View {
        // The lifecycle modifiers sit on both branches' container, so a hidden failed map still
        // reloads in the next foreground session.
        Group {
            if viewModel.loadFailed {
                Color.clear.frame(height: 0)
                    .accessibilityHidden(true)
            } else {
                card
            }
        }
        .onAppear {
            viewModel.setVariant(variant(for: colorScheme))
            // A preview frozen in its loading state would race this real load and could be
            // captured as loaded (`HostProcess.isUnitTesting`, app-wide convention).
            if !HostProcess.isUnitTesting {
                viewModel.appear()
            }
        }
        .onChange(of: colorScheme) { _, newScheme in
            viewModel.setVariant(variant(for: newScheme))
        }
        // Returning from the background does not re-run `onAppear`. Activation can repeat within
        // one session (Control Center, a banner); `appear()` loads at most once per session.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, !HostProcess.isUnitTesting {
                viewModel.appear()
            }
        }
    }

    private var card: some View {
        Theme.RedesignColors.surface
            .aspectRatio(MapImageSource.aspectRatio, contentMode: .fit)
            .overlay { content }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.RedesignColors.surfaceStroke, lineWidth: 1))
            .contentShape(shape)
            .onTapGesture {
                guard let onOpenRegionList else { return }
                openCount += 1
                onOpenRegionList()
            }
            .sensoryFeedback(Theme.Haptics.button, trigger: openCount)
    }

    @ViewBuilder
    private var content: some View {
        if let uiImage = viewModel.imageData.flatMap(UIImage.init(data:)) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Text(viewModel.accessibilityLabel))
                .opensRegionList(onOpenRegionList)
        } else {
            loadingState
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

    private func variant(for scheme: ColorScheme) -> MapImageVariant {
        scheme == .dark ? .night : .day
    }
}

private extension View {
    /// VoiceOver's side of the card-wide tap: the gesture itself is invisible to it, so the one
    /// element each state always has announces as a button, carries the hint, and opens the list
    /// on activation.
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
        AlertMapCardPreviewHost(
            viewModel: .preloaded(
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
#endif
