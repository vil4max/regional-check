import DriveCheckKit
import SwiftUI
import UIKit

/// The inline alert map on the Status tab (ADR 0015). It loads once per phone foreground session,
/// on its own appear or when the scene returns to the foreground with the card on screen, after the
/// status request; again after a pull that fetched a status, and when a new status changes the
/// regions in alarm — never on a timer (REQ-PROVIDER-002, amended 2026-11-12; MAP-sync). It shows
/// only an image loaded under the current status's alarm set (`visibleImageData`).
///
/// Loading and loaded fill one box whose shape comes from `MapImageSource.aspectRatio`, so the
/// Status tab does not reflow when the image lands. A failed map is hidden, with no error text or
/// button (UI-simplify AC-4): a "Regions under alert" row then opens the list (STATUS-reason AC-4). A failure never
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
                VStack(spacing: Theme.Spacing.sm) {
                    card
                    updatedCaption
                }
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
        if let uiImage = viewModel.visibleImageData.flatMap(UIImage.init(data:)) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Text(viewModel.accessibilityLabel))
                .opensRegionList(onOpenRegionList)
        } else {
            loadingState
        }
    }

    /// MAP-sync AC-7: the map's own load time. The line is laid out even while loading, with a
    /// sample time hidden, so the tab does not reflow when the image lands.
    private var updatedCaption: some View {
        let caption = viewModel.updatedCaption
        let sample = String(
            format: String(localized: "map.caption.updated"),
            Date.now.formatted(date: .omitted, time: .shortened)
        )
        return Text(caption ?? sample)
            .font(Theme.RedesignTypography.caption)
            .foregroundStyle(Theme.RedesignColors.textSecondary)
            .frame(maxWidth: .infinity)
            .opacity(caption == nil ? 0 : 1)
            .accessibilityHidden(caption == nil)
    }

    /// MAP-sync AC-8: while the fresh map loads, the card shows a bundled silhouette of the same
    /// raster with every region in one neutral grey, so it never stands empty and never shows an
    /// alarm picture that is not the current one. Made from the upstream day and night renders
    /// (2026-11-13) by recolouring both fills; borders and background are unchanged.
    private var loadingState: some View {
        Image("MapPlaceholder")
            .resizable()
            .scaledToFit()
            .overlay { MapLoadingShimmer() }
            .accessibilityLabel(Text("map.fullscreen.loading"))
            .opensRegionList(onOpenRegionList)
    }

    private func variant(for scheme: ColorScheme) -> MapImageVariant {
        scheme == .dark ? .night : .day
    }
}

/// MAP-sync AC-8: the sign that the map is still coming — a soft highlight sweeping across the
/// silhouette, the skeleton shimmer people know from placeholder cells. It is clipped to the land
/// (the light silhouette's alpha), skipped under Reduce Motion, and left out of test hosts, whose
/// snapshots must not depend on the frame they were captured at.
private struct MapLoadingShimmer: View {
    private static let sweep: TimeInterval = 1.6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if !reduceMotion, !HostProcess.isUnitTesting {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = elapsed.truncatingRemainder(dividingBy: Self.sweep) / Self.sweep
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, highlight, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.5)
                    // From fully left of the map to fully right of it.
                    .offset(x: (phase * 1.5 - 0.5) * proxy.size.width)
                }
            }
            .mask {
                Image("MapPlaceholder")
                    .resizable()
                    .scaledToFit()
                    .environment(\.colorScheme, .light)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var highlight: Color {
        .white.opacity(colorScheme == .dark ? 0.24 : 0.5)
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
