import Foundation

/// Best-effort widget polling: fetch fresh alerts and keep last-known-good on failure.
///
/// WidgetKit calls getTimeline again after the `.after` poll date. That call must
/// attempt a network refresh itself — otherwise polling only re-renders the same
/// stale cache. On transport failure the last good snapshot is preserved, so the
/// widget shows stale last-known status instead of a terminal "no connection".
public enum WidgetTimelineRefresh {
    public static func refresh(
        store: SharedStore = .shared,
        provider: any StatusProviding = UbillingProvider()
    ) async {
        do {
            let snapshot = try await provider.fetchAlerts()
            store.saveSnapshot(snapshot)
        } catch {
            // Keep last-known-good snapshot; freshness tier will mark it stale.
        }
    }
}
