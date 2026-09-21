import DriveCheckKit
import SwiftUI

/// The Status tab (`docs/tasks/redesign.md` §6.1, ADR 0015) — title row, hero, the nearby-alert
/// line, the location-denied card and the inline alert map. The full summary lives on Details;
/// only its safety line stays here (REQ-SURF-005). The scroll view carries no bottom clearance of
/// its own:
/// `MainTabView`'s native `TabView` contributes the tab bar to the safe area, and SwiftUI insets
/// scrolled content by it.
struct StatusView: View {
    var controller: StatusController
    var showsLocationAccessDenied = false
    var mapViewModel: MapViewModel?
    /// Dev-only trace sink; always nil outside DEBUG builds.
    var debugExplanationTraces: ExplanationTraceStore?
    var onOpenLocationSettings: (() -> Void)?
    /// Pushes the read-only region list; the `NavigationStack` that performs the push belongs to
    /// the host (`HomeView`), so this view stays previewable without one.
    var onOpenRegionList: (() -> Void)?
    /// `@Sendable` because `refreshable(action:)` requires it; the pull gesture's handler is the
    /// only caller and runs on the main actor.
    var onRefresh: @Sendable () async -> Void = {}

    @State private var showsDebugTraces = false

    private var accent: Theme.RedesignStatusAccent {
        Theme.RedesignStatusAccent(phase: controller.state.phase, isStale: controller.isDataStale)
    }

    /// `StatusState.symbolName` (not owned by RD-5) only knows about phase, not staleness, so a
    /// stale-but-quiet state would show a checkmark instead of the state table's clock. Staleness
    /// wins here the same way it wins in `accent`.
    private var symbolName: String {
        accent == .stale ? "clock" : controller.state.symbolName
    }

    private var heroTitle: String {
        accent.fullTitle(for: controller.state)
    }

    private var metaTextOverride: String? {
        switch controller.state {
        case .error, .regionUnavailable:
            controller.state.detailText
        default:
            nil
        }
    }

    private var isAlertActive: Bool {
        if case .alarm = controller.state {
            true
        } else {
            false
        }
    }

    private var isChecking: Bool {
        if case .idle = controller.state {
            true
        } else {
            false
        }
    }

    /// The meta line reports staleness even where the accent does not: a stale alarm keeps its
    /// red accent and symbol, so "Last known: … · HH:mm" is where its age is told.
    private var metaAccent: Theme.RedesignStatusAccent {
        controller.isDataStale ? .stale : accent
    }

    private var metaText: String {
        metaTextOverride ?? StatusMetaLine.text(
            accent: metaAccent,
            checkedAt: controller.state.checkedAt,
            lastKnownTitle: controller.lastKnownState?.title
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.RedesignColors.background.ignoresSafeArea()

            // The toolbar is the scroll view's own top bar rather than a sibling overlay with a
            // hand-kept clearance: the bar is then the row's real height at every Dynamic Type
            // size, the pull-to-refresh spinner appears below the row, and the system scroll edge
            // effect, not an opaque backing, keeps scrolled content legible under the title.
            content
                .safeAreaBar(edge: .top, spacing: 0) {
                    StatusToolbar(
                        debugExplanationTraces: debugExplanationTraces,
                        showsDebugTraces: $showsDebugTraces
                    )
                }
        }
        .sensoryFeedback(trigger: controller.state.phase) { _, new in
            switch new {
            case .alarm:
                .warning
            case .quiet:
                .impact(flexibility: .soft, intensity: 0.7)
            case .error, .regionUnavailable:
                .error
            case .idle:
                nil
            }
        }
        #if DEBUG
        .sheet(isPresented: $showsDebugTraces) {
                if let debugExplanationTraces {
                    ExplanationTraceSheet(store: debugExplanationTraces)
                }
            }
        #endif
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: Theme.RedesignSpacing.screenInset) {
                StatusHeroCard(
                    accent: accent,
                    symbolName: symbolName,
                    isAlertActive: isAlertActive,
                    isChecking: isChecking,
                    regionTitle: controller.regionTitle,
                    metaText: metaText,
                    title: heroTitle
                )
                .padding(.top, Theme.RedesignSpacing.toolbarGap)

                if let nearby = StatusNearbyLine.text(
                    region: controller.currentRegion,
                    phase: controller.state.phase,
                    snapshot: controller.lastSnapshot
                ) {
                    StatusNearbyLineView(text: nearby)
                }

                // Directly under the hero, above the map: with location denied the region rests
                // on its fallback, and that must be said on the first screen rather than below
                // the fold (REQ-REGION-009).
                if showsLocationAccessDenied {
                    LocationAccessDeniedCard(onOpenLocationSettings: onOpenLocationSettings)
                }

                if let mapViewModel {
                    AlertMapCard(viewModel: mapViewModel, onOpenRegionList: onOpenRegionList)
                }
            }
            .padding(.horizontal, Theme.RedesignSpacing.screenInset)
        }
        .refreshable(action: onRefresh)
    }
}

#if DEBUG
    /// A container whose map is already loaded. `AppContainer.fixture`'s network is offline to the
    /// map's own loader, so the container's `mapViewModel` never leaves `.loading`, and every
    /// Status snapshot stopped at "Loading map…" — nothing below the map was ever captured, at any
    /// text size. The preloaded model renders the real card at its real height. Not private:
    /// Prefire copies each preview body into the test target, which must see this.
    @MainActor
    func statusPreviewLoadedMap(for container: AppContainer, network: FixtureNetwork) -> MapViewModel {
        .preloaded(
            imageData: FixtureNetwork.previewMapImage,
            loadedAt: AppContainer.fixtureNow,
            statusSource: container.status,
            httpClient: network,
            variant: .night
        )
    }

    // Clear and alert go through the real `AppContainer.fixture()` → `StatusController` pipeline.
    // The fixture clock is fixed at `fetchedAt == now`, so a fixture snapshot never evaluates as
    // stale; checking and stale are previewed at the `StatusHeroCard` level instead.
    #Preview("Status clear") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network)
        StatusView(controller: container.status, mapViewModel: statusPreviewLoadedMap(for: container, network: network))
    }

    // Kharkiv with neighbours under alert: the hero's alarm and the nearby-alert line together.
    #Preview("Status alert") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(region: .kharkiv, network: network)
        StatusView(controller: container.status, mapViewModel: statusPreviewLoadedMap(for: container, network: network))
    }

    #Preview("Status location denied") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network, locationAuthorization: .denied)
        StatusView(
            controller: container.status,
            showsLocationAccessDenied: container.homeViewModel.showsLocationAccessDenied,
            mapViewModel: statusPreviewLoadedMap(for: container, network: network),
            onOpenLocationSettings: {}
        )
    }

    // No cached snapshot and no fetch yet: no nearby line, and the map is still loading, which is
    // the true first-launch state rather than a preview shortcut.
    #Preview("Status no data") {
        let container = AppContainer.fixture(hasCachedSnapshot: false)
        StatusView(controller: container.status, mapViewModel: container.mapViewModel)
    }

    #Preview("Status AX5") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(region: .kharkiv, network: network)
        StatusView(controller: container.status, mapViewModel: statusPreviewLoadedMap(for: container, network: network))
            .dynamicTypeSize(.accessibility5)
    }
#endif
