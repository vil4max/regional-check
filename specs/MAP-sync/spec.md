# MAP-sync: the inline map follows the status

Status: approved (owner, 2026-11-12, with the plan: both decisions below accepted), for 3.4.0
together with LIVEACT-glance. Superseded 2026-11-13 by [MAP-native](../MAP-native/spec.md): the
app draws the map from the status snapshot, so there is no raster to keep in step.

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
- **AC-7** Under a shown map a caption gives the time the map was loaded: "Map updated 21:35" /
  «Карта обновлена 21:35» / «Мапу оновлено 21:35», in the style of the status meta line. While
  the map loads the caption's line stays reserved but empty, so the Status tab does not reflow; a
  hidden (failed) map has no caption. Added by the owner on 2026-11-12 after the stale upstream
  raster was found, in place of any raster check: «Карту обновляем и экстра логики не пишем,
  просто должна быть подпись во сколько карта была обновлена». Supersedes UI-simplify AC-3's
  "the map image carries no caption" for this caption only.
- **AC-8** While the fresh map loads, the card shows a bundled silhouette of the upstream raster
  with every region in one neutral grey (day and night appearances), not an empty box with a
  spinner. It carries no alarm data, so it never presents an old picture as current (ADR 0015).
  Owner, 2026-11-13: «Для карты скачай плейсхолдер и показывай пока не скачали свежий снимок. Не
  красиво при запуске на месте карты пустота и лоадер». A soft highlight sweeps across the
  silhouette while it loads, as in Telegram's placeholder cells, so the wait reads as loading; it
  is skipped under Reduce Motion (owner, 2026-11-13: «Если спиннер убираем то нужна анимация
  загрузки… Есть анимация переливания цветом пустых плейсхолдеров ячеек в тг»).

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

- ~~Upstream renders the raster from the same data as the JSON.~~ **False (measured 2026-11-12,
  21:19–21:37 local):** the map endpoint alternates between a raster that matches the JSON and an
  older raster with only the eastern regions in alarm (the same bytes under several different JSON
  alarm sets); a cache-busting query parameter does not avoid it (7 of 8 busted and 8 of 8 plain
  requests got the old raster at 21:37). Evidence: dev-bank
  `2026-11-12/drivecheck-map-sync/work/` (`lag.log`, `png/`, `buster/`). AC-1 to AC-6 still hold
  for what the app requests and shows, but the Goal is not met while upstream serves the old
  raster: a fresh request can bring it. Owner's decision (2026-11-12): no raster check; the map
  shows the time it was loaded (AC-7).
