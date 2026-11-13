import DriveCheckKit
import SwiftUI

/// The Status tab (ADR 0015) — title row, hero with its reason line (STATUS-reason), the
/// location-denied card and the inline alert map, which opens the region list; a "Regions under
/// alert" row stands in for it while it is hidden. The scroll view carries no bottom clearance of
/// its own:
/// `MainTabView`'s native `TabView` contributes the tab bar to the safe area, and SwiftUI insets
/// scrolled content by it.
struct StatusView: View {
    /// Whether the scroll view draws no edge effect under the title bar, so the hero's glow reaches
    /// the top of the screen (REQ-SURF-012). Details keeps its effect.
    static let hidesTopScrollEdgeEffect = true

    var controller: StatusController
    var showsLocationAccessDenied = false
    /// Dev-only trace sink; always nil outside DEBUG builds.
    var debugExplanationTraces: ExplanationTraceStore?
    var onOpenLocationSettings: (() -> Void)?
    /// Pushes the read-only region list; the `NavigationStack` that performs the push belongs to
    /// the host (`HomeView`), so this view stays previewable without one.
    var onOpenRegionList: (() -> Void)?
    /// `@Sendable` because `refreshable(action:)` requires it; the pull gesture's handler is the
    /// only caller and runs on the main actor.
    var onRefresh: @Sendable () async -> Void = {}
    var isProOwner = false
    var onOpenPro: (() -> Void)?

    @State private var showsDebugTraces = false
    @State private var layoutMetrics = StatusLayoutMetrics()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// REQ-SURF-013: the hero's size and the map card's width cap for the measured screen.
    private var layout: StatusLayout {
        layoutMetrics.layout()
    }

    private var accent: Theme.RedesignStatusAccent {
        controller.accent
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

    /// The meta line reports staleness even where the accent does not: a stale alarm keeps its
    /// red accent and symbol, so "Last known: … · HH:mm" is where its age is told.
    private var metaAccent: Theme.RedesignStatusAccent {
        controller.isDataStale ? .stale : accent
    }

    private var metaText: String {
        metaTextOverride
            ?? StatusMetaLine.text(
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
            // size, and the pull-to-refresh spinner appears below the row. The bar paints nothing:
            // the scroll view hides its top edge effect so the hero's glow is whole behind the
            // title (REQ-SURF-012), and scrolled content passes under the title without blur, an
            // accepted trade-off. Details keeps its edge effect.
            content
                .safeAreaBar(edge: .top, spacing: 0) {
                    StatusToolbar(
                        isProOwner: isProOwner,
                        onOpenPro: onOpenPro,
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
        .modifier(DebugTracesSheet(isPresented: $showsDebugTraces, store: debugExplanationTraces))
    }
}

extension StatusView {
    private var content: some View {
        ScrollView {
            VStack(spacing: Theme.RedesignSpacing.screenInset) {
                // The hero size is read in the transform, in the same layout pass as the height,
                // so the pair always describes the hero that was actually measured.
                aboveMap
                    .onGeometryChange(for: StatusLayoutMetrics.AboveMap.self) { proxy in
                        StatusLayoutMetrics.AboveMap(
                            height: proxy.size.height + Theme.RedesignSpacing.screenInset,
                            isCompactHero: layout.usesCompactHero || dynamicTypeSize.isAccessibilitySize
                        )
                    } action: {
                        layoutMetrics.aboveMap = $0
                    }

                AlertMapCard(
                    snapshot: controller.lastSnapshot,
                    currentRegion: controller.currentRegion,
                    isStale: controller.isDataStale,
                    onOpenRegionList: onOpenRegionList
                )
                .frame(maxWidth: layout.mapMaxWidth ?? .infinity)
            }
            // Full width before measuring: a capped map must not narrow the width it is capped from.
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: {
                layoutMetrics.contentWidth = $0
            }
            .padding(.horizontal, Theme.RedesignSpacing.screenInset)
        }
        // The scroll view's own frame already runs from under the title row to the tab bar or the
        // home indicator; its scroll geometry is not used, because the refresh control's inset
        // would resize the hero and the map during a pull to refresh.
        .onGeometryChange(for: CGFloat.self) {
            $0.size.height
        } action: {
            layoutMetrics.visibleHeight = $0
        }
        .refreshable(action: onRefresh)
        .scrollEdgeEffectHidden(Self.hidesTopScrollEdgeEffect, for: .top)
    }

    private var aboveMap: some View {
        VStack(spacing: Theme.RedesignSpacing.screenInset) {
            StatusHeroCard(
                accent: accent,
                symbolName: controller.presentation.symbolName,
                regionTitle: controller.regionTitle,
                metaText: metaText,
                reasonText: StatusReasonLine.text(
                    region: controller.currentRegion,
                    phase: controller.state.phase,
                    snapshot: controller.lastSnapshot,
                    alarmStartedAt: controller.alarmStartedAt,
                    checkedAt: controller.state.checkedAt
                ),
                title: heroTitle,
                prefersCompactGraphic: layout.usesCompactHero
            )
            .padding(.top, Theme.RedesignSpacing.toolbarGap)

            // Directly under the hero, above the map: with location denied the region rests
            // on its fallback, and that must be said on the first screen rather than below
            // the fold (REQ-REGION-009).
            if showsLocationAccessDenied {
                LocationAccessDeniedCard(onOpenLocationSettings: onOpenLocationSettings)
            }
        }
    }
}

/// The DEBUG-only explanation-trace sheet. A modifier with `#if` inside its body, not `#if`
/// in the middle of `StatusView`'s modifier chain: SwiftFormat versions indent that differently,
/// and CI's newer formatter rejected what the local one wrote.
private struct DebugTracesSheet: ViewModifier {
    @Binding var isPresented: Bool
    let store: ExplanationTraceStore?

    func body(content: Content) -> some View {
        #if DEBUG
            content.sheet(isPresented: $isPresented) {
                if let store {
                    ExplanationTraceSheet(store: store)
                }
            }
        #else
            content
        #endif
    }
}

#if DEBUG
    // Clear and alert go through the real `AppContainer.fixture()` → `StatusController` pipeline.
    // The fixture clock is fixed at `fetchedAt == now`, so a fixture snapshot never evaluates as
    // stale; checking and stale are previewed at the `StatusHeroCard` level instead.
    #Preview("Status clear") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network)
        StatusView(controller: container.status)
    }

    // Kharkiv under alert: the hero's reason line gives the alert's start, not the neighbours.
    // With a list route, as in the app.
    #Preview("Status alert") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(region: .kharkiv, network: network)
        StatusView(
            controller: container.status,
            onOpenRegionList: {}
        )
    }

    // Kyiv quiet while Kyiv Oblast and its ring are under alert: the yellow Stay Alert, explained
    // by the reason line's names (REQ-SURF-010, STATUS-reason AC-1).
    #Preview("Status stay alert") {
        let network = FixtureNetwork(alarmRegions: [.kyivOblast, .chernihiv, .zhytomyr, .cherkasy])
        let container = AppContainer.fixture(region: .kyivCity, network: network)
        StatusView(
            controller: container.status,
            onOpenRegionList: {}
        )
    }

    #Preview("Status location denied") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(network: network, locationAuthorization: .denied)
        StatusView(
            controller: container.status,
            showsLocationAccessDenied: container.homeViewModel.showsLocationAccessDenied,
            onOpenLocationSettings: {}
        )
    }

    // No cached snapshot and no fetch yet: no reason line, and the map shows its outlines in the
    // no-data fill: the true first-launch state.
    #Preview("Status no data") {
        let container = AppContainer.fixture(hasCachedSnapshot: false)
        StatusView(controller: container.status)
    }

    #Preview("Status AX5") {
        let network = FixtureNetwork()
        let container = AppContainer.fixture(region: .kharkiv, network: network)
        StatusView(controller: container.status)
            .dynamicTypeSize(.accessibility5)
    }
#endif
