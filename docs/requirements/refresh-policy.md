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

## Requirements

Numbered requirements (RD-R, 2026-09-17). They restate the rules above without changing them; tests cite these IDs. Text approved by the owner on 2026-09-17 (gate G1).

### REQ-REFRESH-001 — Fetch only for an active surface

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2, P4

Given the phone tab shell or a CarPlay session is open\
When it appears, or the driver taps Refresh\
Then the app fetches immediately, and it sends no request while neither surface is active

### REQ-REFRESH-002 — Adaptive shared polling interval

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a surface is active\
When the next poll is scheduled\
Then the base interval is 60 s, 30 s while the current region is in alarm, 300 s under Low Power Mode, thermal ≥ serious or a constrained path (wins over alarm), with ±10 % jitter and one ref-counted timer for phone and CarPlay

### REQ-REFRESH-003 — One retry for transient errors

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a fetch fails with a transient `URLError` (timeout, connection lost, cannot connect, DNS)\
When the failure happens\
Then the app retries once after 2 s

### REQ-REFRESH-004 — CarPlay refresh cycle

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1

Given CarPlay connects or the driver taps Refresh on CarPlay\
When fetches fail\
Then the cycle makes up to 3 attempts with 2 s then 4 s backoff, stops while rate limited, and a new cycle supersedes the old one without cancelling the request shared with the phone

### REQ-REFRESH-005 — Rate limit backoff

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given the provider returns HTTP 429\
When the next request is due\
Then the app waits for `Retry-After` (seconds or HTTP date) or backs off 30 s → 60 s → … up to 5 min, skips scheduled polls in that window, and still allows a manual refresh

### REQ-REFRESH-006 — Stale threshold

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a snapshot with `checkedAt` (server `cachedat`, else local fetch time)\
When `now − checkedAt` exceeds 2 × the current base interval\
Then Status, CarPlay and Live Activity show the data as stale

### REQ-REFRESH-007 — CarPlay freshness by age

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1, P2

Given CarPlay shows a cached status\
When a request fails\
Then a fresh cached status stays in the title, and a stale one is shown with its age and without a status marker

### REQ-REFRESH-008 — Widget reload schedule

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a widget timeline is built\
When it schedules the next reload\
Then it uses 180 s in alarm, 300 s when quiet, 120 s when idle, and a failed widget fetch keeps the last known good snapshot

### REQ-REFRESH-009 — Widget freshness tiers

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a widget shows a snapshot\
When its age crosses 3 min or 10 min\
Then it marks the time with ⚠, keeps the real status visible, and a known alarm stays red and is never replaced by a connection error screen

