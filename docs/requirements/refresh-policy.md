# Refresh policy

Application-side polling, retry, and freshness rules for Drive Check. Upstream API limits live in `docs/requirements/aerial-alerts-provider.md` — this document is the app contract.

## Request triggers

| Trigger | Network |
|---------|---------|
| Session open (phone tab shell / CarPlay connect) | Immediate fetch |
| Manual Refresh | Immediate fetch |
| Region change | Local select from `AlertsSnapshot`, then background fetch |
| Periodic timer while session active | Yes, adaptive interval |
| Background with no phone UI and no CarPlay | No |

## Adaptive intervals (`RefreshPolicy`)

| Condition | Base interval |
|-----------|--------------:|
| Default | 60 s |
| Current region alarm | 30 s |
| Low Power Mode, thermal ≥ serious, constrained path (Low Data Mode) | 300 s (wins over alarm) |

Each sleep applies ±10 % jitter. Interval is recomputed every cycle and when `NSProcessInfoPowerStateDidChange` fires. Phone and CarPlay share one ref-counted timer on `StatusController`.

Load vs Ubilling **2 rps** host limit: at 60 s ≈ **0.017 rps** from the timer alone.

## Retries and 429

- One retry after **2 s** for transient `URLError` (timeout, connection lost, cannot connect, DNS).
- CarPlay refresh cycle (connect, manual Refresh): up to **3 attempts** of the fetch above, with **2 s → 4 s** backoff between attempts; no further attempts while rate limited. A new cycle supersedes the running one without cancelling the in-flight request shared with the phone UI. Rationale: a CarPlay-only cold launch on weak cellular often loses the first request, and the driver has no other surface to recover from.
- HTTP **429**: parse `Retry-After` (delta-seconds or HTTP-date); else exponential backoff 30 s → 60 s → … capped at **5 minutes**.
- While the rate-limit window is open, **scheduled** polls are skipped; manual refresh may still attempt.

## Freshness

- Requests use `URLRequest` with `.reloadIgnoringLocalCacheData` and `timeoutInterval = 15`.
- Display `checkedAt` = server `cachedat` when parseable, else local `fetchedAt`.
- Stale UI when `now - checkedAt > 2 × current base interval` (Status, CarPlay, Live Activity).
- CarPlay judges freshness only by `checkedAt`: a failed request with fresh cached data keeps the cached status in the title. Stale cached status is shown with its age and without a status marker, never as a bare current status.

## Widget polling and freshness (`WidgetTimelineRefresh`, `WidgetTimelineBuilder`)

Widget extensions perform best-effort autonomous polling and render scheduled visual freshness transitions:

- **Autonomous polling**: on `getTimeline`, the widget attempts a background fetch via `WidgetTimelineRefresh`. On transport failure, the last-known-good snapshot is preserved in `SharedStore`.
- **Reload schedule (`.after`)**:
  - Current region alarm: **180 s** (3 min).
  - Quiet / all clear: **300 s** (5 min).
  - Idle / initial: **120 s** (2 min).
  These intervals respect WidgetKit's daily reload budget (~40–70 reloads/day) while staying far faster than default iOS background app refresh.
- **Visual freshness tiers**:
  - `fresh` (< 3 min): real alert status, clean timestamp `Updated: HH:mm`.
  - `aging` (3–10 min): real status preserved, `⚠ Updated: HH:mm`, alarm stays red, quiet turns amber (`staleData`).
  - `expired` (> 10 min): real status preserved (never hidden behind a terminal "no connection" screen), `⚠ Updated: HH:mm`. Alarms remain high-visibility red (`attention`) to prevent false senses of security.

## Battery

A small HTTPS poll while the screen or CarPlay is active is cheap next to continuous location + reverse geocoding. Prefer kilometer accuracy, distance filter, and geocode throttling (`docs/requirements/region-model.md`) over stretching the poll interval alone.

## Related

- ADR 0004 — adaptive refresh and rate-limit behavior  
- Provider wiki limits — `docs/requirements/aerial-alerts-provider.md`
