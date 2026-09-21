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

## Fetch floor and cache serving

The provider documents a limit of **2 requests per second per host** and states that exceeding
it returns HTTP 429 and may bring a permanent ban; it caches raw data server-side for 3 seconds.

- The **first fetch of a session is immediate** and never throttled — it is the one the driver
  waits for.
- After it, at least **10 s** must pass between any two network fetches, **whatever triggered
  them**: session open, pull to refresh, region change, scene activation and a CarPlay connect
  can no longer stack. 10 s sits well above the provider's 3 s server cache, inside which a
  refetch returns identical data anyway, and well below the 27 s a scheduled alarm poll can
  reach after jitter, so the floor never swallows a scheduled poll.
- Inside the floor a refresh **serves the held snapshot** and completes without a request. It is
  not a failure and does not mark the data stale.
- The floor is measured from the last **successful** fetch. Serving cache only means something
  when there is a fresh answer to serve; after a failure there is none, and the spacing of
  retries is already governed by REQ-REFRESH-003, REQ-REFRESH-004 (CarPlay's 2 s and 4 s
  attempts, which a floor counted from every attempt would silently cancel) and REQ-REFRESH-005.

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

Given the phone Status surface or a CarPlay session is open\
When it appears, the driver pulls the Status screen to refresh, or the driver taps Refresh in CarPlay\
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
Then Status, CarPlay and Live Activity preserve the last known alert phase and show it as stale

`No Current Data` is reserved for a failed request when no saved snapshot exists.
A failed request never replaces a cached clear or alert phase with an unavailable phase.

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

### REQ-REFRESH-010 — Fetch floor and cache serving

Status: approved — owner, 2026-09-20 ("утверждаю", for the refresh-policy amendment proposed in
`docs/tasks/ia-simplification-3.0.md` §3)

Core: P2

Given a fetch succeeded less than 10 s ago in this session\
When any trigger asks for a refresh — pull to refresh, scene activation, region change, a CarPlay connect or the timer\
Then no request is sent, the held snapshot stays in place, and the refresh completes without recording a failure or marking the data stale; the first fetch of a session and any retry after a failed fetch are never subject to the floor

### REQ-REFRESH-011 — Pull to refresh answers with a haptic only

Status: approved — owner, 2026-09-21 ("при пултурефреш - лишних сообщений не надо, главное ловить хаптик что пулпрошел - не важно попали в интервал или нет, главное ловить ерор от апи": no extra messages on pull to refresh; what matters is a haptic that the pull went through, whether or not it fell inside the interval, and catching an API error)

Core: P1

Given the driver pulls the Status tab to refresh\
When the refresh finishes\
Then a success haptic plays whether a request was sent or the fetch floor (REQ-REFRESH-010) held it, an error haptic plays only when the provider request failed, and no text message appears; refreshes the driver did not start — scene activation, the timer, a region change — play no haptic
