# MAP-sync: the inline map follows the status

Status: approved (owner, 2026-11-12, with the plan: both decisions below accepted), for 3.4.0
together with LIVEACT-glance.

## Request

Owner, 2026-11-12, with a screenshot of the Status tab:

> Карта запаздывает

> При пул ту рефреш не обновилась. И при открытии пуш тоже. Хотя статус обновился. Неконсинстентное

> Делаем здесь вместе с фичей.

## Goal

The inline alert map on the Status tab never shows a different alarm picture from the status
above it for longer than one map request takes.

## What happens today (evidence, 2026-11-12)

- The map loads once per phone foreground session: on the card's appear or the scene's return to
  the foreground (`RegionalCheck/Views/MapCardView.swift`, `onChange(of: scenePhase)`, since 3.2.0,
  commit `4364c9c`), after the status settles and `MapViewModel.postStatusDelay`.
- Within a session nothing reloads a loaded map. A status poll (every 30 s in alarm) or a pull that
  changes which regions are in alarm updates the status, the "Regions under alert" row and the Live
  Activity, but leaves the image (`MapViewModel.swift`, `appear()` guard `imageData == nil`).
- The pull to refresh retries only a failed map (`MapViewModel.retryIfFailed`; UI-simplify AC-4,
  ADR 0015 "the map stays out of pull-to-refresh").
- Opening the app from an alert notification while it is already in the foreground (a banner tap)
  is not a new session: the status changes, the map does not. From the background it reloads.
- The map request uses the default HTTP cache policy; the status request uses
  `.reloadIgnoringLocalCacheData` (`UbillingProvider.swift:134`). Upstream answers the map with
  `Cache-Control: max-age=60, private, must-revalidate`, no `ETag` or `Last-Modified` (measured
  `curl -D -`, 2026-11-12 17:27 UTC), so a reload within 60 s may return the cached picture.
- At 17:28 UTC the upstream map and status JSON agreed (15 regions in alarm, Kyiv city clear).
  Whether the upstream raster lags the JSON after a change is being measured
  (dev-bank `2026-11-12/drivecheck-map-sync/work/lag.log`); the result goes into the plan.

## Acceptance criteria

- **AC-1** When an accepted status snapshot changes the set of regions in alarm compared with the
  set the shown map was loaded under, the map reloads once, after `postStatusDelay`. Within one
  set no status poll adds a map request.
- **AC-2** A pull to refresh whose own status request returns a new snapshot reloads the map,
  loaded or failed, after that request settles and `postStatusDelay`. A pull held by the
  REQ-REFRESH-010 floor, failed or rate-limited retries only a failed map, as before (plan point 1).
- **AC-3** The card never shows an image loaded under a different alarm set from the status shown
  above it: while such a reload runs it shows the placeholder, as at a session's start. A reload
  under the same set keeps the image until the new one lands. A failed reload hides the card
  (UI-simplify AC-4 unchanged).
- **AC-4** Every map request bypasses the local HTTP cache, like the status request.
- **AC-5** Load discipline stays: one map request in flight at most, a newer request supersedes an
  older one (the generation counter), the map always follows the status request by
  `postStatusDelay`, and a tab switch or a repeated activation within one set adds no request.
- **AC-6** VoiceOver's map label names the same counts as the status it was loaded under
  (unchanged behaviour, kept under the new reloads).

## Out of scope

- Drawing our own map from the JSON (ADR 0015 keeps the upstream raster).
- CarPlay, widgets, the Live Activity: none shows the map.
- Polling for the map on a timer: the map reloads only on the enumerated triggers.

## Decisions to make (owner)

1. REQ-PROVIDER-002 clause 2 forbids a surface's own automatic trigger. AC-1 adds one: "a map
   reload when an accepted status changes the set of regions in alarm", bounded by the shared poll
   (at most one per poll, 30 s at the fastest). Amend clause 2, ADR 0015 ("stays out of
   pull-to-refresh") and UI-simplify AC-4 ("a loaded map is never re-requested by the pull").
2. AC-3: the placeholder while a changed-set reload runs (proposed), or the old image with a
   loading mark.

## Assumptions

- Upstream renders the raster from the same data as the JSON; if the lag measurement shows a
  delay longer than `postStatusDelay`, the plan adds a bounded second reload, and this spec is
  amended first.
