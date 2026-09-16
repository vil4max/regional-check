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
