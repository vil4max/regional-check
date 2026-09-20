# Region model

Canonical region catalog, storage migration, resolver rules, and location → region path for Drive Check.

Source of truth for keys: live Ubilling `states` object (pinned in `RegionalCheckTests/Fixtures/aerialalerts.json`). **25** oblast/city keys. Crimea and Sevastopol are **not** in the feed and are not app regions.

## Catalog (`AlertRegion`)

| Case | Ubilling `apiKey` |
|------|-------------------|
| `kyivCity` | `м. Київ` |
| `vinnytsia` | `Вінницька область` |
| `volyn` | `Волинська область` |
| `dnipropetrovsk` | `Дніпропетровська область` |
| `donetsk` | `Донецька область` |
| `zhytomyr` | `Житомирська область` |
| `zakarpattia` | `Закарпатська область` |
| `zaporizhzhia` | `Запорізька область` |
| `ivanoFrankivsk` | `Івано-Франківська область` |
| `kyivOblast` | `Київська область` |
| `kirovohrad` | `Кіровоградська область` |
| `luhansk` | `Луганська область` |
| `lviv` | `Львівська область` |
| `mykolaiv` | `Миколаївська область` |
| `odesa` | `Одеська область` |
| `poltava` | `Полтавська область` |
| `rivne` | `Рівненська область` |
| `sumy` | `Сумська область` |
| `ternopil` | `Тернопільська область` |
| `kharkiv` | `Харківська область` |
| `kherson` | `Херсонська область` |
| `khmelnytskyi` | `Хмельницька область` |
| `cherkasy` | `Черкаська область` |
| `chernivtsi` | `Чернівецька область` |
| `chernihiv` | `Чернігівська область` |

Unknown Ubilling keys are ignored and logged. A selected region missing from the latest `AlertsSnapshot` surfaces as `StatusState.regionUnavailable` (distinct from network `.error`).

## Storage migration (`RegionStore`)

| Key | Content |
|-----|---------|
| `selected_region_v1` | Legacy `{ kind: kyivCity \| oblast(name) }` JSON |
| `selected_region_v2` | `AlertRegion` raw-value Codable |
| `follows_location_v1` | Bool; vestigial since 3.0 — see below |

On load: decode v2 if present; else decode v1 → resolve to `AlertRegion` → save v2 → remove v1.

The region always follows location (owner, 2026-09-20; ADR 0015). Releases before 3.0 stored
`false` under `follows_location_v1` — `shared.region.followsLocation.v1` in the App Group — when
the driver pinned a region by hand. The key is vestigial: it stays where it is so an existing
install migrates without a write, the app never reads it as anything but `true`, and nothing
writes it. The migration from standard defaults removes the legacy copy without carrying its
value over. An install that had a pinned region keeps that region as its last region until the
tracker commits another one.

## Resolver (`AlertRegionResolver`)

Input: reverse-geocode `cityName` + `administrativeArea` (preferred locale `uk_UA` via `MapKitReverseGeocoder`).

Normalization: trim, collapse whitespace, lowercase, unify apostrophes, strip `.`.

| Rule | Behavior |
|------|----------|
| Kyiv city | City or area matching `київ` / `kyiv` / `kiev` / `м київ` → `.kyivCity` (wins over oblast) |
| Oblast | Match normalized `apiKey` or English `… oblast` after expanding `обл.` / `область` / `Oblast` stems |
| Unknown | `nil` — keep current region; log unresolved names |

Examples covered by tests: `Чернігівська обл.`, `Chernihiv Oblast`, spaced/cased variants, `Kyiv` vs `Київська область`.

## Location → region path

```text
CLLocationManager
  desiredAccuracy = kilometer
  distanceFilter = 2000 m
  activityType = automotiveNavigation
        │
        ▼
LocationFix (accuracy + timestamp)
        │
        ▼
RegionSelection
        │
        ▼
RegionTracker.evaluate
  1. drop bad fix (accuracy < 0 or > 1 km, age > 60 s)
  2. throttle geocode (≥ 60 s AND ≥ 5 km from last geocode)
  3. ReverseGeocoding → AlertRegionResolver
  4. hysteresis candidate → commit
        │
        ▼
selectedRegion + RegionStore
        │
        ▼
StatusController.setRegion → apply AlertsSnapshot locally (+ background refresh)
```

Outside Ukraine (`countryCode != UA`): keep the last selected region (Kyiv city when there is none) and show the outside-Ukraine info sheet when the location changes from inside to outside Ukraine, and once at launch if already outside; it does not repeat while the location stays outside (REQ-REGION-008, owner 2026-09-17).

### Tracker constants (`RegionTracker`)

| Constant | Value | Why |
|----------|------:|-----|
| `maxHorizontalAccuracyMeters` | 1000 | Match kilometer accuracy mode; reject coarse cell fixes |
| `maxFixAge` | 60 s | Drop Core Location cached startup fixes |
| `geocodeMinInterval` | 60 s | Limit MapKit / power use while driving |
| `geocodeMinDistanceMeters` | 5000 | Avoid re-geocoding chatter at the same place |
| `hysteresisMinDuration` | 90 s | Require sustained presence before auto-switch |
| `hysteresisMinDistanceMeters` | 5000 | Or clear travel into the new region |

Hysteresis: a resolved region ≠ current becomes a **candidate** (timestamp + origin). Commit only if every subsequent successful resolve agrees **and** (≥ 90 s since candidate **or** ≥ 5 km from candidate origin). Any disagreement resets the candidate. The tracker is the only path to a region change.

On commit, the phone shows a non-modal notice “Region changed: …” that the driver can dismiss (no CarPlay modal). The notice has no Undo: restoring the previous region would be a manual pin under another name (owner, 2026-09-20).

## Location authorization

| Status | App behavior |
|--------|----------------|
| `notDetermined` | Request when-in-use |
| authorized | Start updates when clients > 0 |
| `denied` / `restricted` | Stop updates; the region stays the last one, Kyiv city when there is none; Status tab shows the denial, says that enabling location gives a more precise region, and offers Open Settings; CarPlay short text only |

Policy helper: `LocationAuthorizationPolicy.isBlocked`.

## Related

- ADR 0002 — canonical `AlertRegion` enum  
- ADR 0003 — geocoding seam + resolver  
- ADR 0005 — tracker debounce / hysteresis  
- Architecture overview: `docs/engineering/architecture.md`  
- Provider / polling: `docs/requirements/aerial-alerts-provider.md`

## Requirements

Numbered requirements (RD-R, 2026-09-17). They restate the rules above without changing them; tests cite these IDs. Text approved by the owner on 2026-09-17 (gate G1).

### REQ-REGION-001 — Catalog of 25 regions

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a provider response\
When it contains unknown keys or lacks the selected region\
Then unknown keys are ignored and logged, and a missing selected region shows `regionUnavailable`, distinct from a network error

### REQ-REGION-002 — Stored selection migration

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P3

Given a stored `selected_region_v1` and no v2\
When the app loads the selection\
Then it resolves v1 to `AlertRegion`, saves v2, removes v1, and treats a missing follow-location flag as true

Amended 2026-09-20 with REQ-REGION-003's retirement: the flag is vestigial, so a stored `false` is treated as true as well, and the flag is never written. The Given/When/Then above is unchanged.

### REQ-REGION-003 — Manual pin stops following

Status: retired — owner, 2026-09-20 ("не надо руками ничего пинить, есть локация - ведем по локации, нет - берем киев, и показываем что включите локацию для более точного определения места": nothing is pinned by hand; with a location the region follows it, without one it is Kyiv, and the app says that enabling location gives a more precise region). Approved 2026-09-17, in force through 2.x.

Core: P3

Retired, not rewritten: 3.0 has no manual pin and no follow-location toggle (ADR 0015), so the
requirement has no subject. The ID is not reused. Text as last approved:

Given follow location is on\
When the driver pins a region\
Then follow location turns off until the driver turns it back on

### REQ-REGION-004 — Resolver rules

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P2

Given a reverse-geocoded city and area\
When they name Kyiv city, an oblast, or nothing known\
Then Kyiv city wins over the oblast, oblast names match in Ukrainian and English forms, and an unknown result keeps the current region

### REQ-REGION-005 — Location fix filtering and geocode throttle

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1

Given follow location is on\
When a location fix arrives\
Then fixes worse than 1 km or older than 60 s are dropped, and reverse geocoding runs only after ≥ 60 s and ≥ 5 km since the last geocode

### REQ-REGION-006 — Region switch hysteresis

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1

Given a resolved region differs from the current one\
When later resolves agree\
Then the switch commits only after ≥ 90 s or ≥ 5 km from the candidate origin, and any disagreement resets the candidate

### REQ-REGION-007 — Region change notice

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval); amended 2026-09-20 under the charter amendments approved that day ("ундо на твое усмотрение": Undo is at the agent's discretion — decision: keep the notice, drop Undo, because Undo restores the previous region, which is a manual pin under another name)

Core: P1

Given the tracker commits a new region\
When the switch happens\
Then the phone shows a non-modal, dismissible "Region changed" notice with no Undo, and CarPlay shows no modal

### REQ-REGION-008 — Outside Ukraine keeps the last region

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval)

Core: P1, P2

Given the device location changes from inside Ukraine to outside, or the app launches while already outside\
When the location is resolved\
Then the last selected region stays selected (Kyiv city only if there is none) and the outside-Ukraine sheet appears once, not again while the location stays outside

### REQ-REGION-009 — Location access denied

Status: approved — owner, 2026-09-17 ("Всё", everything, for RD-R text approval); amended 2026-09-20 under the charter amendments approved that day (the pick-region tip is deleted: it told the driver to do something the app no longer offers)

Core: P1

Given location access is denied or restricted\
When the app needs location\
Then updates stop, the region falls back to Kyiv, the Status tab says that enabling location gives a more precise region and offers Open Settings, and CarPlay shows short text only

"Falls back to Kyiv" is the rule REQ-REGION-008 already states: the last region stays selected, and it is Kyiv city when there is none.

### REQ-REGION-010 — The location prompt waits for onboarding

Status: approved — owner, 2026-09-20 ("исправить - запрашиваем когда юзер на главном экране": fix it, ask once the user is on the main screen)

Core: P3, P4

Given a first launch, with onboarding not yet finished\
When the app starts its session\
Then the status loads at once for the default region, location updates — and with them the system permission prompt — start only after the driver finishes onboarding, and a session that never started location does not release a location client it never took

