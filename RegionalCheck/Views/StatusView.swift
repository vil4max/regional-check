import DriveCheckKit
import SwiftUI

/// The Status tab (`docs/tasks/redesign.md` §6.1, ADR 0015) — title row, hero, grouped list
/// (location denied, "Also watching"), the inline alert map, Summary card. The scroll view carries no bottom clearance
/// of its own:
/// `MainTabView`'s native `TabView` contributes the tab bar to the safe area, and SwiftUI insets
/// scrolled content by it.
struct StatusView: View {
    var controller: StatusController
    var sourceLabel: String?
    var showsLocationAccessDenied = false
    var secondaryRegion: AlertRegion?
    var secondaryRegionStatus: AlertStatus?
    var mapViewModel: MapViewModel?
    var statusDetailsViewModel: StatusDetailsViewModel?
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

            // The toolbar is the scroll view's own top inset rather than a sibling overlay with a
            // hand-kept clearance: the inset is then the row's real height at every Dynamic Type
            // size, and the pull-to-refresh spinner appears below the row, not behind it.
            content
                .safeAreaInset(edge: .top, spacing: 0) {
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
                .padding(.top, Theme.RedesignSpacing.toolbarFade)

                // Directly under the hero, above the map: with location denied the region rests
                // on its fallback, and that must be said on the first screen rather than below
                // the fold (REQ-REGION-009). The card draws nothing when it has no row.
                StatusGroupedListCard(
                    secondaryRegion: secondaryRegion,
                    secondaryStatus: secondaryRegionStatus,
                    showsLocationAccessDenied: showsLocationAccessDenied,
                    onOpenLocationSettings: onOpenLocationSettings
                )

                if let mapViewModel {
                    AlertMapCard(viewModel: mapViewModel, onOpenRegionList: onOpenRegionList)
                }

                StatusSummaryCard(
                    sourceLabel: sourceLabel,
                    statusDetailsViewModel: statusDetailsViewModel,
                    snapshot: controller.lastSnapshot,
                    accent: accent
                )
            }
            .padding(.horizontal, Theme.RedesignSpacing.screenInset)
            .statusDetailsLifecycle(statusDetailsViewModel)
        }
        .refreshable(action: onRefresh)
    }
}

#if DEBUG
    // Clear and alert go through the real `AppContainer.fixture()` → `StatusController` pipeline
    // (genuine data). `AppContainer.fixture`'s clock is fixed at `fetchedAt == now`, so a fixture
    // snapshot can never evaluate as stale, and previews render after the fixture's synchronous
    // settle — there's no way to catch it mid-"checking" either. Both would need a toggle in
    // `AppContainerFixture.swift`, which isn't owned by RD-5 (`RegionalCheck/App/`). Checking and
    // stale are previewed at the `StatusHeroCard` component level instead — flagged in the RD-5
    // report as an open question for whoever next touches that fixture.
    #Preview("Status clear") {
        let container = AppContainer.fixture()
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel
        )
    }

    #Preview("Status alert") {
        let container = AppContainer.fixture(region: .kharkiv)
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel
        )
    }

    #Preview("Status location denied") {
        let container = AppContainer.fixture(locationAuthorization: .denied)
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            showsLocationAccessDenied: container.homeViewModel.showsLocationAccessDenied,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onOpenLocationSettings: {}
        )
    }

    // No cached snapshot and no fetch yet: details are idle and there is nothing to summarise, so
    // the Summary card must be absent rather than a box holding only its header.
    #Preview("Status no data") {
        let container = AppContainer.fixture(hasCachedSnapshot: false)
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel
        )
    }

    #Preview("Status AX5") {
        let container = AppContainer.fixture(region: .kharkiv)
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel
        )
        .dynamicTypeSize(.accessibility5)
    }
#endif
