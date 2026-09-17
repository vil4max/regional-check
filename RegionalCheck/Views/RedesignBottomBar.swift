import SwiftUI

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

    var body: some View {
        // Apple docs (GlassEffectContainer): combine adjacent Liquid Glass shapes in one
        // container so SwiftUI renders them together — improves rendering and lets the tab bar
        // and round button morph into each other if a future task adds that interaction.
        GlassEffectContainer(spacing: Theme.RedesignControlSizes.tabBarToActionGap) {
            HStack(spacing: Theme.RedesignControlSizes.tabBarToActionGap) {
                tabBar
                actionButton
            }
        }
        .padding(.horizontal, Theme.RedesignSpacing.screenInset)
        .padding(.bottom, Theme.RedesignControlSizes.tabBarBottomInset)
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
