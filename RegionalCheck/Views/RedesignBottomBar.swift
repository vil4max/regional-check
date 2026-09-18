import SwiftUI

/// The largest bottom safe-area reading reported by any `RedesignBottomBar` instance's own
/// `.background` probe — `reduce` takes the max because a stale 0 from an initial layout pass
/// should never win over an already-measured real value.
private struct BottomSafeAreaPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// RD-4: the redesign's bottom bar — a glass tab bar (Status, Regions) plus a separate 62 pt round
/// action button to its right (Refresh on Status, Search entry point on Regions; owner rulings
/// 4.1 #2/#3, `docs/tasks/rd-4-bottom-bar.md`).
///
/// This draws its own chrome rather than the system tab bar's automatic Liquid Glass style: the
/// round button must sit in the exact same 62 pt row as the tab bar with a fixed 12 pt gap, and
/// the tab bar needs the Pro-palette `tabSelectedFill`/`barStroke` chrome (RD-2 `geometry-and-
/// tokens.md` §2) — neither is a customization point the system tab bar exposes. `MainTabView`
/// switches content with a plain `switch`, not `TabView` (no hide modifier fully suppressed the
/// system tab bar's glass background on this iOS 27 build — see `MainTabView.body`); this view
/// owns the visible chrome and its accessibility labels.
struct RedesignBottomBar: View {
    /// What the round button does and shows, driven by the selected tab and live status state.
    enum Action: Equatable {
        case refresh(isLoading: Bool, isStale: Bool)
        case search

        /// Status always shows Refresh, Regions always shows Search — never the other way around
        /// (REQ-SURF-002; the brief's rejected "a search-role tab triggers Refresh"). Pure so
        /// `MainTabViewModelTests` can cover every tab/state combination without a live view.
        static func forSelectedTab(_ tab: MainTabView.Tab, isLoading: Bool, isDataStale: Bool) -> Self {
            switch tab {
            case .status:
                .refresh(isLoading: isLoading, isStale: isDataStale)
            case .regions:
                .search
            }
        }
    }

    @Binding var selectedTab: MainTabView.Tab
    let action: Action
    let palette: Theme.RedesignPalette
    let onActionTapped: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var bottomSafeArea: CGFloat = 0

    var body: some View {
        // `MainTabView` places this inside `.safeAreaInset(edge: .bottom)`, which already reserves
        // the device's own bottom safe area for this content — adding the full 24 pt target on top
        // double-counts it (58 pt of gap on a 34 pt-safe-area device against a mockup that means
        // 24). Only the shortfall between the target and what the safe area already provides is
        // this view's own padding to add, with an 8 pt floor so the bar never sits flush with a
        // home indicator on a device that has one.
        let extraInset = Self.extraBottomInset(safeArea: bottomSafeArea)

        // Apple docs (GlassEffectContainer): combine adjacent Liquid Glass shapes in one
        // container so SwiftUI renders them together — improves rendering and lets the tab bar
        // and round button morph into each other if a future task adds that interaction.
        return GlassEffectContainer(spacing: Theme.RedesignControlSizes.tabBarToActionGap) {
            HStack(spacing: Theme.RedesignControlSizes.tabBarToActionGap) {
                tabBar
                actionButton
            }
        }
        .padding(.horizontal, Theme.RedesignSpacing.screenInset)
        .padding(.bottom, extraInset)
        // A `GeometryReader` in `.background` measures without containing the glass content: glass
        // effects render unreliably when built directly inside a `GeometryReader`'s own closure.
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: BottomSafeAreaPreferenceKey.self, value: proxy.safeAreaInsets.bottom)
            }
        )
        .onPreferenceChange(BottomSafeAreaPreferenceKey.self) { bottomSafeArea = $0 }
    }

    /// The bar's own bottom padding beyond the device's safe area — shared with
    /// `RedesignBottomFade`, whose footprint has to match this exactly or the fade stops short of
    /// (or overshoots) where the bar actually sits.
    static func extraBottomInset(safeArea: CGFloat) -> CGFloat {
        max(Theme.RedesignControlSizes.tabBarBottomInset - safeArea, 8)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.status, label: "tab.status", systemImage: "steeringwheel")
            tabButton(.regions, label: "tab.regions", systemImage: "list.bullet")
        }
        .frame(height: Theme.RedesignControlSizes.tabBarHeight)
        .frame(maxWidth: .infinity)
        .redesignGlassSurface(in: Capsule())
        .overlay(Capsule().strokeBorder(palette.barStroke, lineWidth: 1))
        // Not a real `TabView`/`UITabBar` (see the file header), so VoiceOver needs to be told
        // this container is a tab bar explicitly; combined with each item's `.isButton` +
        // `.isSelected` below, this is what gets VoiceOver to read "Status, tab, 1 of 2" instead
        // of two unrelated buttons.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }

    private func tabButton(_ tab: MainTabView.Tab, label: LocalizedStringKey, systemImage: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? palette.tabSelectedLabel : Theme.RedesignColors.textSecondary)
            .background {
                if isSelected {
                    Capsule()
                        .fill(palette.tabSelectedFill)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Round action button

    /// `.glassEffect(_:in:)` anchors to the modified view's own bounds (Apple docs: "the material
    /// fills the entirety of the Text frame, which includes the padding"), so the frame must be
    /// established on the icon itself before the glass modifier — applying it to a separate
    /// `Circle()` background layer left the glass unbounded and it rendered oversized.
    private var actionButton: some View {
        let icon = actionIcon
            .font(.body.weight(.semibold))
            .foregroundStyle(isStale ? Theme.RedesignColors.textOnStale : Theme.RedesignColors.textPrimary)
            .frame(width: Theme.RedesignControlSizes.actionButton, height: Theme.RedesignControlSizes.actionButton)

        return Button(action: onActionTapped) {
            actionSurface(icon)
                .opacity(isChecking ? 0.6 : 1)
        }
        .buttonStyle(HapticButtonStyle(feedback: Theme.Haptics.icon))
        .disabled(isChecking)
        .accessibilityLabel(Text(actionAccessibilityLabel))
    }

    @ViewBuilder
    private var actionIcon: some View {
        switch action {
        case let .refresh(isLoading, _):
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: "arrow.clockwise")
            }
        case .search:
            Image(systemName: "magnifyingglass")
        }
    }

    /// Filled `statusStale` when data is stale; otherwise glass — `.glassEffect(.regular.
    /// interactive())` normally, `RedesignGlass.fill` under Reduce Transparency (11). Not reusing
    /// `redesignGlassSurface` (RD-2, `Theme+Redesign.swift`) here: that helper renders `.regular`
    /// glass for the static tab bar container, while this is a tappable control that wants the
    /// `.interactive()` press response — a small local variant rather than a change to RD-2's file.
    @ViewBuilder
    private func actionSurface(_ icon: some View) -> some View {
        if isStale {
            icon.background(Circle().fill(Theme.RedesignColors.statusStale))
        } else if reduceTransparency {
            icon
                .background(Theme.RedesignGlass.fill(reduceTransparency: true), in: Circle())
                .overlay(Circle().strokeBorder(palette.actionButtonStroke, lineWidth: 1))
        } else {
            icon
                .glassEffect(.regular.interactive(), in: Circle())
                .overlay(Circle().strokeBorder(palette.actionButtonStroke, lineWidth: 1))
        }
    }

    private var isChecking: Bool {
        if case let .refresh(isLoading, _) = action {
            return isLoading
        }
        return false
    }

    private var isStale: Bool {
        if case let .refresh(_, isStale) = action {
            return isStale
        }
        return false
    }

    private var actionAccessibilityLabel: LocalizedStringKey {
        switch action {
        case let .refresh(isLoading, _):
            isLoading ? "Checking…" : "Refresh"
        case .search:
            "Search regions"
        }
    }
}

/// Fades scrollable content to `background` before the floating `RedesignBottomBar`'s own
/// footprint — its height, `tabBarBottomInset`, and the device's bottom safe area — rather than a
/// fixed guess at that footprint. A fixed-height fade that stops short of the safe area leaves
/// content legible in the gap below the bar and through its glass (found on a real device capture:
/// a region name readable below the bar, another row showing through it).
///
/// `GeometryReader` sits inside `.ignoresSafeArea`, not outside it: the reader still measures the
/// un-ignored safe area at that point in the layout, while the modifier lets the gradient itself
/// paint into it.
struct RedesignBottomFade: View {
    /// Distance the gradient fades in above the bar's own solid footprint.
    ///
    /// A plain two-stop (linear) gradient over this distance is not enough on its own: opacity at
    /// a fixed point close to the footprint rises only as `1 - k/fadeInDistance` for that point's
    /// own distance `k` from the footprint, so making a line of text immediately above the bar
    /// (as little as ~20 pt away) actually invisible would need an impractically large distance —
    /// hundreds of points, eating most of the screen — while a shorter one (the original 40 pt,
    /// then a "1.5× bar height" 96 pt) still left it clearly legible (found on real device
    /// captures: a card's last line, then "Sumy Oblast" and its red "Alert" label, both readable
    /// crossing the bar). `stops` below front-loads opacity instead: the gradient is already at
    /// 0.9 by the last 20% of this distance, so anything that close to the footprint is nearly
    /// solid regardless of how far the fade extends above it; distance still governs how gradual
    /// the fade looks further up, where nothing is close enough to read either way.
    static let fadeInDistance: CGFloat = 96

    var body: some View {
        GeometryReader { proxy in
            let footprint = Theme.RedesignControlSizes.tabBarHeight
                + RedesignBottomBar.extraBottomInset(safeArea: proxy.safeAreaInsets.bottom)
                + proxy.safeAreaInsets.bottom
            let total = footprint + Self.fadeInDistance
            LinearGradient(
                stops: [
                    .init(color: Theme.RedesignColors.background.opacity(0), location: 0),
                    .init(
                        color: Theme.RedesignColors.background.opacity(0.15),
                        location: 0.4 * Self.fadeInDistance / total
                    ),
                    .init(
                        color: Theme.RedesignColors.background.opacity(0.97),
                        location: 0.55 * Self.fadeInDistance / total
                    ),
                    .init(color: Theme.RedesignColors.background, location: Self.fadeInDistance / total)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: total)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}

extension RedesignBottomFade {
    /// The largest bottom safe area any current Face ID device reports (iPhone 17 Pro Max class);
    /// `scrollClearance` sizes itself against this rather than a specific device's value, so it
    /// stays correct as new devices ship with a slightly taller or shorter one.
    private static let assumedMaxDeviceSafeArea: CGFloat = 40

    /// Bottom padding for scrollable content so its last row clears the bar with the same margin
    /// the fade covers. A fixed estimate, not a live safe-area read — scroll clearance only needs
    /// to be "enough" — but it has to track `RedesignBottomBar.extraBottomInset`'s own formula:
    /// `tabBarHeight + extraBottomInset(safeArea) + safeArea` is *not* constant once
    /// `extraBottomInset` stops being a flat 24, and the largest it gets is at the largest safe
    /// area (the 8pt floor no longer buys anything back once the safe area exceeds 16pt), not at
    /// zero — a stale `34` here would under-reserve on exactly the devices most likely to need it.
    static let scrollClearance: CGFloat = Theme.RedesignControlSizes.tabBarHeight
        + RedesignBottomBar.extraBottomInset(safeArea: assumedMaxDeviceSafeArea)
        + assumedMaxDeviceSafeArea
        + fadeInDistance
}

#if DEBUG
    /// A spinner frozen at one phase, for the checking-state preview only.
    ///
    /// `ProgressView()`'s indeterminate animation has no stable frame, so a snapshot of it never
    /// matches its own baseline twice. `ProgressViewStyle` resolves through the environment, so
    /// applying this on the preview reaches the `ProgressView` inside `actionIcon` and leaves what
    /// ships untouched. The ring is a stand-in, not the system artwork: the baseline it produces
    /// documents the button's layout and the checking treatment, not the spinner's own pixels.
    ///
    /// Internal, not `private`: Prefire copies each preview's body into its generated test file, so
    /// anything a preview references has to be visible from outside this file.
    struct PreviewFrozenProgressViewStyle: ProgressViewStyle {
        func makeBody(configuration _: Configuration) -> some View {
            Circle()
                .trim(from: 0, to: 0.8)
                .stroke(.foreground, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 18, height: 18)
        }
    }

    #Preview("Bottom bar clear") {
        VStack {
            Spacer()
            RedesignBottomBar(
                selectedTab: .constant(.status),
                action: .refresh(isLoading: false, isStale: false),
                palette: .standard,
                onActionTapped: {}
            )
        }
        .background(Theme.RedesignColors.background)
    }

    #Preview("Bottom bar checking") {
        VStack {
            Spacer()
            RedesignBottomBar(
                selectedTab: .constant(.status),
                action: .refresh(isLoading: true, isStale: false),
                palette: .standard,
                onActionTapped: {}
            )
        }
        .background(Theme.RedesignColors.background)
        .progressViewStyle(PreviewFrozenProgressViewStyle())
    }

    #Preview("Bottom bar stale Pro") {
        VStack {
            Spacer()
            RedesignBottomBar(
                selectedTab: .constant(.status),
                action: .refresh(isLoading: false, isStale: true),
                palette: .pro,
                onActionTapped: {}
            )
        }
        .background(Theme.RedesignColors.background)
    }

    #Preview("Bottom bar regions search") {
        VStack {
            Spacer()
            RedesignBottomBar(
                selectedTab: .constant(.regions),
                action: .search,
                palette: .standard,
                onActionTapped: {}
            )
        }
        .background(Theme.RedesignColors.background)
    }
#endif
