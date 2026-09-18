import SwiftUI

extension EnvironmentValues {
    /// Carries the cold-start hand-off's shared `Namespace.ID` from `ColdStartRootView` down to
    /// `StatusHeroGraphic`, wherever it's instantiated (`StatusHeroCard`, several layers below
    /// `MainTabView`, and `ColdStartHeroView`, a sibling of `MainTabView` under the overlay) —
    /// an environment value rather than an explicit parameter, so this doesn't need threading
    /// through `MainTabView`/`StatusView`/`StatusHeroCard`'s own initializers just to reach one
    /// leaf view. `nil` outside the cold-start root, so `StatusHeroGraphic` only opts into
    /// `matchedGeometryEffect` when there's an actual hand-off in progress.
    @Entry var coldStartHeroNamespace: Namespace.ID?

    /// Carries the cold-start hand-off's `AccessibilityFocusState` binding down to
    /// `StatusHeroCard`, the same way `coldStartHeroNamespace` reaches `StatusHeroGraphic` —
    /// `ColdStartRootView` drives focus, but the focus target is `StatusHeroCard` itself
    /// (REQ-LAUNCH-005: VoiceOver should land on the status, not on `MainTabView` as a whole),
    /// several view layers below where the state lives.
    @Entry var coldStartHeroFocus: AccessibilityFocusState<Bool>.Binding?
}

/// Mirrors `ColdStartHeroMatchedGeometry`: `accessibilityFocused(_:)` takes a non-optional
/// `AccessibilityFocusState<Bool>.Binding`, so this is a no-op outside the cold-start root.
struct ColdStartHeroFocusTarget: ViewModifier {
    let binding: AccessibilityFocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let binding {
            content.accessibilityFocused(binding)
        } else {
            content
        }
    }
}

/// `matchedGeometryEffect(id:in:isSource:)` takes a non-optional `Namespace.ID` — this applies it
/// only once a namespace actually exists, so `StatusHeroGraphic` stays a no-op outside the
/// cold-start hand-off (every other screen and every existing snapshot) instead of gaining a
/// namespace dependency it doesn't have a value for.
struct ColdStartHeroMatchedGeometry: ViewModifier {
    let namespace: Namespace.ID?
    let isSource: Bool

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: "coldStartHero", in: namespace, isSource: isSource)
        } else {
            content
        }
    }
}
