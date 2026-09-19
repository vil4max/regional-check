import DriveCheckKit
import SwiftUI

/// RD-5/RD-6: the redesigned Status (Home) tab (`docs/tasks/redesign.md` §6.1) — navigation row,
/// hero, Summary card, grouped list, all scrolling under the RD-4 bottom bar behind
/// `RedesignBottomFade`. The map card is gone; RD-6's "Alert map" row and full-screen cover live
/// in `StatusGroupedListCard`/`AlertMapRow`.
struct StatusView: View {
    var controller: StatusController
    var isPro = false
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
    var onShowPaywall: (() -> Void)?
    var onOpenLocationSettings: (() -> Void)?

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

    private var metaText: String {
        metaTextOverride ?? StatusMetaLine.text(
            accent: accent,
            followsLocation: followsLocation,
            checkedAt: controller.state.checkedAt,
            lastKnownTitle: controller.lastKnownState?.title
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.RedesignColors.background.ignoresSafeArea()

            content
                .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: Theme.RedesignSpacing.contentTop) }

            // A fade over the scroll viewport's bottom edge, not a mask on the ScrollView's
            // content: the RD-4 bottom bar floats above it (redesign.md §6.1, "content must
            // scroll ... the bottom bar floats above a fade"). Sized to the bar's actual
            // footprint, not a fixed guess — see `RedesignBottomFade`.
            RedesignBottomFade()

            StatusToolbar(
                isPro: isPro,
                onShowPaywall: onShowPaywall,
                onShowInfo: onShowInfo,
                debugExplanationTraces: debugExplanationTraces,
                showsDebugTraces: $showsDebugTraces
            )
            .frame(maxHeight: .infinity, alignment: .top)
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
                .padding(.top, Theme.RedesignSpacing.screenInset)

                StatusSummaryCard(
                    isPro: isPro,
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
            .padding(.bottom, RedesignBottomFade.scrollClearance)
        }
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
            isPro: container.homeViewModel.isPro,
            sourceLabel: container.homeViewModel.sourceLabel,
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {},
            onShowPaywall: {}
        )
    }

    #Preview("Status alert Pro") {
        let container = AppContainer.fixture(region: .kharkiv, isPro: true)
        StatusView(
            controller: container.status,
            isPro: container.homeViewModel.isPro,
            sourceLabel: container.homeViewModel.sourceLabel,
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {},
            onShowPaywall: {}
        )
    }

    #Preview("Status location denied") {
        let container = AppContainer.fixture(locationAuthorization: .denied)
        StatusView(
            controller: container.status,
            isPro: container.homeViewModel.isPro,
            sourceLabel: container.homeViewModel.sourceLabel,
            showsLocationAccessDenied: container.homeViewModel.showsLocationAccessDenied,
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {},
            onShowPaywall: {},
            onOpenLocationSettings: {}
        )
    }

    #Preview("Status AX5") {
        let container = AppContainer.fixture(region: .kharkiv, isPro: true)
        StatusView(
            controller: container.status,
            isPro: container.homeViewModel.isPro,
            sourceLabel: container.homeViewModel.sourceLabel,
            followsLocation: container.regions.followsLocation,
            mapViewModel: container.mapViewModel,
            statusDetailsViewModel: container.statusDetailsViewModel,
            onShowInfo: {},
            onShowPaywall: {}
        )
        .dynamicTypeSize(.accessibility5)
    }
#endif
