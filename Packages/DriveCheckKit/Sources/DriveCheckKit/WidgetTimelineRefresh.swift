import Foundation

/// Best-effort widget polling: fetch fresh alerts and keep last-known-good on failure.
///
/// WidgetKit calls getTimeline again after the `.after` poll date. That call must
/// attempt a network refresh itself — otherwise polling only re-renders the same
/// stale cache. On transport failure the last good snapshot is preserved, so the
/// widget shows stale last-known status instead of a terminal "no connection".
public enum WidgetTimelineRefresh {
    /// A timeline reload is a scheduled poll, so a stored 429 window skips it (REQ-PROVIDER-002
    /// clause 4). Saved deadlines are capped, so one further ahead was written before the clock
    /// moved back and is ignored.
    public static func refresh(
        store: SharedStore = .shared,
        provider: any StatusProviding = UbillingProvider(),
        now: Date = Date()
    ) async {
        if let until = store.loadRateLimitedUntil(),
            (0...RetryAfterParser.maxHold).contains(until.timeIntervalSince(now))
        {
            return
        }
        do {
            let snapshot = try await provider.fetchAlerts()
            store.saveSnapshot(snapshot)
        } catch let UbillingError.rateLimited(until) {
            store.saveRateLimitedUntil(min(until, now.addingTimeInterval(RetryAfterParser.maxHold)))
        } catch {
            // Keep last-known-good snapshot; freshness tier will mark it stale.
        }
    }
}
