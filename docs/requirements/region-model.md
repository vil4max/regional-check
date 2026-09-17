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
| `follows_location_v1` | Bool; default **true** when absent |

On load: decode v2 if present; else decode v1 → resolve to `AlertRegion` → save v2 → remove v1.

Manual pin (`RegionSelection.pin`) sets `follows_location_v1 = false`. Toggle “Follow location” restores GPS-driven updates.

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
RegionSelection (followsLocation?)
        │ no → ignore
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

Outside Ukraine (`countryCode != UA`): pin to `.kyivCity` and show the outside-Ukraine info sheet once per session.

### Tracker constants (`RegionTracker`)

| Constant | Value | Why |
|----------|------:|-----|
| `maxHorizontalAccuracyMeters` | 1000 | Match kilometer accuracy mode; reject coarse cell fixes |
| `maxFixAge` | 60 s | Drop Core Location cached startup fixes |
| `geocodeMinInterval` | 60 s | Limit MapKit / power use while driving |
| `geocodeMinDistanceMeters` | 5000 | Avoid re-geocoding chatter at the same place |
| `hysteresisMinDuration` | 90 s | Require sustained presence before auto-switch |
| `hysteresisMinDistanceMeters` | 5000 | Or clear travel into the new region |

Hysteresis: a resolved region ≠ current becomes a **candidate** (timestamp + origin). Commit only if every subsequent successful resolve agrees **and** (≥ 90 s since candidate **or** ≥ 5 km from candidate origin). Any disagreement resets the candidate. Manual pin skips the tracker entirely.

On auto-commit, UI shows a non-modal notice “Region changed: …” with Undo (no CarPlay modal).

## Location authorization

| Status | App behavior |
|--------|----------------|
| `notDetermined` | Request when-in-use |
| authorized | Start updates when clients > 0 |
| `denied` / `restricted` | Stop updates; Status tab shows denial + Open Settings + pick region tip; CarPlay short text only |

Policy helper: `LocationAuthorizationPolicy.isBlocked`.

## Related

- ADR 0002 — canonical `AlertRegion` enum  
- ADR 0003 — geocoding seam + resolver  
- ADR 0005 — tracker debounce / hysteresis  
- Architecture overview: `docs/engineering/architecture.md`  
- Provider / polling: `docs/requirements/aerial-alerts-provider.md`

## Requirements

Numbered requirements (RD-R, 2026-09-17). They restate the rules above without changing them; tests cite these IDs. Text approval: owner (gate G1).

### REQ-REGION-001 — Catalog of 25 regions

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P2

Given a provider response\
When it contains unknown keys or lacks the selected region\
Then unknown keys are ignored and logged, and a missing selected region shows `regionUnavailable`, distinct from a network error

### REQ-REGION-002 — Stored selection migration

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P3

Given a stored `selected_region_v1` and no v2\
When the app loads the selection\
Then it resolves v1 to `AlertRegion`, saves v2, removes v1, and treats a missing follow-location flag as true

### REQ-REGION-003 — Manual pin stops following

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P3

Given follow location is on\
When the driver pins a region\
Then follow location turns off until the driver turns it back on

### REQ-REGION-004 — Resolver rules

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P2

Given a reverse-geocoded city and area\
When they name Kyiv city, an oblast, or nothing known\
Then Kyiv city wins over the oblast, oblast names match in Ukrainian and English forms, and an unknown result keeps the current region

### REQ-REGION-005 — Location fix filtering and geocode throttle

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P1

Given follow location is on\
When a location fix arrives\
Then fixes worse than 1 km or older than 60 s are dropped, and reverse geocoding runs only after ≥ 60 s and ≥ 5 km since the last geocode

### REQ-REGION-006 — Region switch hysteresis

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P1

Given a resolved region differs from the current one\
When later resolves agree\
Then the switch commits only after ≥ 90 s or ≥ 5 km from the candidate origin, and any disagreement resets the candidate

### REQ-REGION-007 — Region change notice

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P1

Given the tracker commits a new region\
When the switch happens\
Then the phone shows a non-modal "Region changed" notice with Undo, and CarPlay shows no modal

### REQ-REGION-008 — Outside Ukraine

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P2

Given the device location is outside Ukraine\
When the location is resolved\
Then the app pins Kyiv city and shows the outside-Ukraine sheet once per session

### REQ-REGION-009 — Location access denied

Status: inferred — owner review required (documented behavior above, now numbered)

Core: P1

Given location access is denied or restricted\
When the app needs location\
Then updates stop, the Status screen shows the denial with Open Settings and a pick-region tip, and CarPlay shows short text only

### Proposed amendment to REQ-REGION-008 — Outside Ukraine keeps the last region

Status: proposed — owner rulings DS-3 O1 and O2 (2026-09-17); replaces REQ-REGION-008 when approved

Core: P1, P2

Given the device location changes from inside Ukraine to outside, or the app launches while already outside\
When the location is resolved\
Then the last selected region stays selected (Kyiv city only if there is none) and the outside-Ukraine sheet appears once, not again while the location stays outside

