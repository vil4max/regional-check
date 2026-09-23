# Aerial alerts data provider

Drive Check reads regional air-raid status from the public [Ubilling Aerial Alerts API](https://wiki.ubilling.net.ua/doku.php?id=aerialalertsapi).

## Endpoint

```
https://ubilling.net.ua/aerialalerts/
```

Implementation: `Packages/DriveCheckKit/Sources/DriveCheckKit/UbillingProvider.swift`.

Response fields (verified against a live response, 2026-08-02):

| Field | Meaning |
| --- | --- |
| `source` | Upstream data source selected by Ubilling |
| `cachedat` | Server cache timestamp in `Europe/Kyiv` (`YYYY-MM-DD HH:mm:ss`) |
| `states[region].alertnow` | `true` = alert active, `false` = all clear |
| `states[region].changed` | Last change time for that region |

Region keys are Ukrainian oblast names plus `м. Київ` for Kyiv city. A live catalog pin lives in `RegionalCheckTests/Fixtures/aerialalerts.json` (currently **25** keys; Crimea and Sevastopol are not present in the default feed).

## Ubilling limits (upstream)

From the official wiki (as of 2026):

| Rule | Value |
| --- | --- |
| Rate limit | **2 requests per second per host** (since 2024-02-13) |
| Over limit | HTTP **429** |
| Server cache | Raw data cached for **3 seconds** |

The API is public (no keys). Ubilling describes it as informational only — not for safety-critical decisions. Prefer official sources when making important decisions.

### Optional query parameters

Documented on the Ubilling wiki; Drive Check uses the default JSON endpoint only:

| Parameter | Purpose |
| --- | --- |
| `?source=` | Explicit upstream: `default`, `skog`, `klimenko`, `jaam`, `aiu`, `ual` |
| `?raw` | Unprocessed payload for a chosen source |
| `?xml=true` | XML instead of JSON |
| `?map=` | Alert map image (`true`, `nightmode`, `rednight`, `webp`) |
| `?webalerts` | HTML alert board |

## Drive Check refresh policy

The app keeps requests well below Ubilling limits. Polling runs only while an iPhone screen or CarPlay session is active.

| Trigger | Network request |
| --- | --- |
| Screen open (`onAppear`) | Yes — immediate check |
| Region change (GPS or manual) | Prefer local selection from the last full snapshot; network refresh follows |
| Manual **Refresh** | Yes |
| Periodic refresh while session active | Yes — see interval below |
| App in background (no active UI / CarPlay) | No |

### Polling interval

`StatusController.beginPeriodicRefresh()` starts a shared timer used by both iPhone (`MainTabView`) and CarPlay (`CarPlaySceneDelegate`). Reference counting ensures one timer when both surfaces are active. Interval comes from `RefreshPolicy` (±10 % jitter), recomputed each cycle and when Low Power Mode changes.

| Condition | Interval |
| --- | ---: |
| Baseline | **60 s** |
| Current region in alarm | **30 s** |
| Low Power Mode, thermal ≥ serious, or expensive/constrained path | **300 s** (wins over alarm) |

- First fetch on open/connect is still immediate; the timer only schedules later checks
- Stops when the phone tab shell disappears and CarPlay disconnects
- Full app policy: `docs/requirements/refresh-policy.md`

At 60-second intervals the app sends about **0.017 rps** from periodic polling alone — far below the 2 rps host limit. Event-driven refreshes (open, region change, manual) may add a few extra requests but remain safe in normal use.

### Why a shorter interval is still polite

The 3-second server cache means data *can* be fresh to within three seconds. The real ceiling is the **2 rps** host limit and being a good neighbor — not “faster polling cannot help.” Five minutes as the only interval is not required by Ubilling; it is a product/battery choice. Battery cost of a kilobyte HTTPS request while the screen is on is small compared with continuous high-accuracy GPS + reverse geocoding (see `docs/requirements/refresh-policy.md` once added).

## Battery notes

- Polling runs only during an active session (screen on or CarPlay). Display power dominates a once-per-minute request.
- Cellular cost is radio wakeups (~60/hour at a 60 s interval), not payload size (~hundreds of KB/hour).
- The larger cost in this app today is location: default best accuracy with no `distanceFilter`, plus reverse geocoding on each update. Tightening location settings saves more than lengthening the poll interval.
- Listing all regions in the UI does **not** add requests: one response already contains every region.

## Operational notes

- Prefer adaptive polling (60 s / 30 s / 300 s) over a fixed multi-minute interval; keep well under 2 rps.
- If Ubilling returns HTTP 429, treat it as rate limiting and back off (`Retry-After` when present). The UI currently surfaces a generic unavailable state on fetch failure; backoff hardening is planned.
- Do not hammer the endpoint (for example every few seconds). The 3-second cache does not justify that load.

## Requirements

Numbered requirements (RD-R, 2026-09-17). They restate the rules above without changing them; tests cite these IDs. Text approved by the owner on 2026-09-17 (gate G1).

### REQ-PROVIDER-001 — Default JSON endpoint

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2, P3

Given the app needs status\
When it requests the provider\
Then it uses the default JSON endpoint and reads `states[region].alertnow` and `cachedat` (Europe/Kyiv)

### REQ-PROVIDER-002 — Polite load

Status: approved — owner, 2026-09-18 ("согласен с двумя пунктами, всегда опираемся на документацию убилинг чтобы нас не заблочили", agreed with both points, we always rely on Ubilling's documentation so we do not get blocked); replaces the 2026-09-17 text, which named no trigger set, window or number and so could not be falsified

Core: P2, P4

Grounded in Ubilling's own published limits (see "Ubilling limits (upstream)"
above, from the [API wiki](https://wiki.ubilling.net.ua/doku.php?id=aerialalertsapi)):
2 requests per second per host since 2024-02-13, HTTP 429 over the limit, and a
3-second server cache. The owner's reason for grounding it there rather than in
our own idea of politeness: being blocked costs the data source entirely.

Given every surface — phone, CarPlay, widgets, Live Activity, Siri\
When the app issues provider requests\
Then all four clauses hold:

1. **One shared periodic refresh.** A single ref-counted timer serves every
   surface; no surface starts a second one (REQ-REFRESH-002), at the adaptive
   60 s / 30 s / 300 s interval.
2. **Every other request has an enumerated trigger**: a user Refresh, a widget
   timeline reload, a Siri request (REQ-SURF-011), or a surface appearing — the
   phone's inline alert map (once per session). No surface adds an automatic trigger of its own, and no render or update
   loop fetches.
3. **Counted, not assumed.** In a fixture session driving phone, CarPlay and
   widget together, the number of provider requests equals the number of
   triggers exercised.
4. **HTTP 429 is honoured**, backing off on `Retry-After` when present
   (`UbillingRetryTests`), and a scheduled refresh is skipped inside a
   rate-limit window.

Amended 2026-09-21: the CarPlay Map tab left clause 2's list when the owner removed the tab
(REQ-SURF-006); CarPlay no longer requests the map image at all.
Amended 2026-09-22: a Siri request joined clause 2's list with REQ-SURF-011 (owner, the same day);
it is one trigger, none inside the REQ-REFRESH-010 floor, and like every trigger its single
transient-error retry is bounded by REQ-REFRESH-003.
Amended 2026-09-23: a tap on the Live Activity's Refresh button (REQ-SURF-009) is a user Refresh
under clause 2, not a new automatic trigger. It goes through the app's own manual refresh, like a
pull on the Status tab: the REQ-REFRESH-010 floor holds it while the same process fetched less
than 10 s ago, and, as REQ-REFRESH-005 allows for a manual refresh, a rate-limit window does not.
Its rate is bounded by the driver's taps.

Clause 3 proves the app's trigger discipline; it does not measure a rate. The
rate claim is argued from the trigger set: at the shortest adaptive interval the
shared timer contributes about 0.033 rps, and the enumerated event triggers are
driver-initiated or surface-lifecycle events that cannot recur faster than a
person can produce them — two orders of magnitude below the host limit. If
Ubilling publishes a stricter figure or an interval floor, that is a finding and
this requirement changes with it rather than the reverse.

### Pending trigger-list clarification

Status: proposed, not an amendment to the approved REQ-PROVIDER-002 text.

The closure audit found a mismatch between clause 2's literal list and existing
behavior: phone entry, CarPlay connection, region changes and a loaded map's
appearance-variant change also issue requests. The earlier refresh-policy table
already describes phone entry and region changes. The proposed clarification is
to enumerate those lifecycle and selection triggers explicitly, alongside manual
Refresh, widget reload and first map appearance. Retrying a failed request is
bounded by REQ-REFRESH-003/004 rather than counted as another user trigger.

Keep the current behavior until this requirement decision is resolved. The
counting fixture uses successful requests, three JSON triggers and four map
triggers, with no periodic tick in its logical session. It verifies that repeated
presentation reads and unchanged map variants add no requests. It does not prove
host-wide rate limiting or cover every lifecycle/selection trigger. In particular,
separate surfaces can produce bursts; an average polling rate is not a proof of
a per-second upper bound. Do not mark all of REQ-PROVIDER-002 accepted from this
fixture alone.

### REQ-PROVIDER-003 — Informational source

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given the app shows provider data\
When the Details tab is open\
Then it states that the data is informational, as the provider does

The Details tab absorbed the About screen that this requirement first named (ADR 0015, accepted
2026-09-20); the obligation is unchanged.

