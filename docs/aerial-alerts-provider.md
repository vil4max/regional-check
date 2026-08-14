# Aerial alerts data provider

Drive Check reads regional air-raid status from the public [Ubilling Aerial Alerts API](https://wiki.ubilling.net.ua/doku.php?id=aerialalertsapi).

## Endpoint

```
https://ubilling.net.ua/aerialalerts/
```

Implementation: `RegionalCheck/Data/UbillingProvider.swift`.

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
- Full app policy: `docs/refresh-policy.md`

At 60-second intervals the app sends about **0.017 rps** from periodic polling alone — far below the 2 rps host limit. Event-driven refreshes (open, region change, manual) may add a few extra requests but remain safe in normal use.

### Why a shorter interval is still polite

The 3-second server cache means data *can* be fresh to within three seconds. The real ceiling is the **2 rps** host limit and being a good neighbor — not “faster polling cannot help.” Five minutes as the only interval is not required by Ubilling; it is a product/battery choice. Battery cost of a kilobyte HTTPS request while the screen is on is small compared with continuous high-accuracy GPS + reverse geocoding (see `docs/refresh-policy.md` once added).

## Battery notes

- Polling runs only during an active session (screen on or CarPlay). Display power dominates a once-per-minute request.
- Cellular cost is radio wakeups (~60/hour at a 60 s interval), not payload size (~hundreds of KB/hour).
- The larger cost in this app today is location: default best accuracy with no `distanceFilter`, plus reverse geocoding on each update. Tightening location settings saves more than lengthening the poll interval.
- Listing all regions in the UI does **not** add requests: one response already contains every region.

## Operational notes

- Prefer adaptive polling (60 s / 30 s / 300 s) over a fixed multi-minute interval; keep well under 2 rps.
- If Ubilling returns HTTP 429, treat it as rate limiting and back off (`Retry-After` when present). The UI currently surfaces a generic unavailable state on fetch failure; backoff hardening is planned.
- Do not hammer the endpoint (for example every few seconds). The 3-second cache does not justify that load.
