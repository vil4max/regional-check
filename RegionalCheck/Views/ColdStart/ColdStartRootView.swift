import SwiftUI

/// Wires `ColdStartOverlay` above `MainTabView` for the real app (not the DEBUG screenshot
/// phases, which want a static, predictable frame — see `RegionalCheckApp.rootContent`).
///
/// `showsColdStart` is `View` `@State`, not something on the `App` itself: it must survive
/// `scenePhase` changes (background/foreground) within one process but never persist across a
/// real process relaunch, which is exactly a `View`'s state lifetime for a view that's created
/// once at the root and never removed.
struct ColdStartRootView: View {
    @Environment(AppContainer.self) private var container
    @State private var showsColdStart = true
    @AccessibilityFocusState private var heroIsFocused: Bool
    /// Shared with `StatusHeroGraphic` (via `coldStartHeroNamespace`) so the overlay's hero can
    /// `matchedGeometryEffect` onto `StatusHeroCard`'s actual on-screen frame — wherever the Status
    /// tab's `ScrollView` and an optional map card above it put it that launch — instead of a
    /// hardcoded position that only happens to match today's layout.
    @Namespace private var heroNamespace

    private var status: StatusController {
        container.status
    }

    var body: some View {
        MainTabView()
            .overlay {
                if showsColdStart {
                    ColdStartOverlay(
                        hasCachedStatus: status.lastSnapshot != nil,
                        awaitStatusSettled: { await status.awaitStatusSettled() },
                        currentAccent: currentAccent,
                        onFinished: {
                            showsColdStart = false
                            // REQ-LAUNCH-005: VoiceOver focus lands on the Status hero once the
                            // overlay ends, rather than staying wherever it was (nowhere, since
                            // the overlay itself is accessibility-hidden throughout) — or on
                            // `MainTabView` as a whole, which said only "you're somewhere in the
                            // app," not "here is the status."
                            heroIsFocused = true
                        }
                    )
                }
            }
            .environment(\.coldStartHeroNamespace, heroNamespace)
            .environment(\.coldStartHeroFocus, $heroIsFocused)
    }

    /// `nil` while genuinely unknown (`.idle`, no cache and no resolved network state yet);
    /// `StatusController.init()` resolves this synchronously when a cached snapshot exists, so a
    /// cached launch never observes `nil` here at all.
    private func currentAccent() -> Theme.RedesignStatusAccent? {
        let phase = status.state.phase
        guard phase != .idle else { return nil }
        return Theme.RedesignStatusAccent(phase: phase, isStale: status.isDataStale)
    }
}
