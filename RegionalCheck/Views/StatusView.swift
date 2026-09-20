import DriveCheckKit
import SwiftUI

/// RD-5/RD-6: the redesigned Status (Home) tab (`docs/tasks/redesign.md` §6.1) — navigation row,
/// hero, Summary card, grouped list. The scroll view carries no bottom clearance of its own:
/// `MainTabView`'s native `TabView` contributes the tab bar to the safe area, and SwiftUI insets
/// scrolled content by it. The map card is gone; RD-6's "Alert map" row and full-screen cover
/// live in `StatusGroupedListCard`/`AlertMapRow`.
struct StatusView: View {
    var controller: StatusController
    var sourceLabel: String?
    var showsLocationAccessDenied = false
    /// Whether the current region follows the driver's location automatically, for the meta line's
    /// "Automatic"/"Manual" word. `RegionSelection.followsLocation` isn't owned by RD-5; `HomeView`
    /// reads it and passes it down rather than this view reaching into the container itself.
    var followsLocation = true
    var secondaryRegion: AlertRegion?
    var secondaryRegionStatus: AlertStatus?
    var mapViewModel: MapViewModel?
    var statusDetailsViewModel: StatusDetailsViewModel?
    /// Dev-only trace sink; always nil outside DEBUG builds.
    var debugExplanationTraces: ExplanationTraceStore?
    var onShowInfo: (() -> Void)?
    var onOpenLocationSettings: (() -> Void)?
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
            followsLocation: followsLocation,
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
                        onShowInfo: onShowInfo,
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

                StatusSummaryCard(
                    sourceLabel: sourceLabel,
                    statusDetailsViewModel: statusDetailsViewModel,
                    snapshot: controller.lastSnapshot,
                    accent: accent
                )

                StatusGroupedListCard(
                    secondaryRegion: secondaryRegion,
                    secondaryStatus: secondaryRegionStatus,
                    showsLocationAccessDenied: showsLocationAccessDenied,
                    mapViewModel: mapViewModel,
                    onOpenLocationSettings: onOpenLocationSettings
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
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {}
        )
    }

    #Preview("Status alert") {
        let container = AppContainer.fixture(region: .kharkiv)
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {}
        )
    }

    #Preview("Status location denied") {
        let container = AppContainer.fixture(locationAuthorization: .denied)
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            showsLocationAccessDenied: container.homeViewModel.showsLocationAccessDenied,
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {},
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
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {}
        )
    }

    #Preview("Status AX5") {
        let container = AppContainer.fixture(region: .kharkiv)
        StatusView(
            controller: container.status,
            sourceLabel: container.homeViewModel.sourceLabel,
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {}
        )
        .dynamicTypeSize(.accessibility5)
    }
#endif
