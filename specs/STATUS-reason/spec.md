# STATUS-reason: one reason line under the status instead of the overview rows

Status: approved (owner, 2026-11-13, with the plan: D2 accepted). Ships in one release with
MAP-native in 3.4.0, which is held until then and was never submitted (owner, 2026-11-13: «Надо не 3.5.0 в версию, а просто сделать апдейт в 3.4.0»).

## Request

Owner, 2026-11-13, with a screenshot of the Status tab in build 3.4.0 (131): "Stay Alert", Kyiv,
"Nearby: Kyiv Oblast, Chernihiv Oblast +2", "Regions under alert: 13 of 25", and a map with only
the east in red:

> Тот текст про регионы рядом, во-первых, не соответствует карте. Во-вторых, сколько регионов в
> Украине под тревогой, видно по картам. И получается, что это абсолютно не несут пользы эти
> тексты. Сколько регионов рядом и сколько вообще в тревоге. Нужно подумать над тем, как их либо
> убрать, либо свести в какую-то информацию более полезную для пользователя, чем ничего не
> значащие подписи.

Owner's choice among the proposed options (2026-11-13): «Причина в подзаголовок» — remove the
card; one reason line under the status ("Alert nearby: …" for Stay Alert, "Alert since 12:05"
during an alert, nothing extra at the all-clear); the region list opens from the map.

## Findings (2026-11-13)

- The rows were right and the map was wrong. At 10:38 UTC the status feed had Kyiv Oblast and
  Chernihiv Oblast under alert; a fetch at 10:40 UTC returned 14 regions in alarm and a map that
  matched them. The screenshot's map is byte-identical (md5 `aa02e176…`) to a stale raster the
  upstream map endpoint returned intermittently on 2026-11-12: 17 single-sample returns in 159
  one-minute samples (dev-bank `2026-11-12/drivecheck-map-sync/work/lag.log`). That defect is
  outside this spec (see Out of scope).
- The "Regions under alert N of 25" row repeats what the map shows, and the map already opens the
  region list on tap (`MapCardView.swift`, `opensRegionList`).
- "Nearby" is the only explanation of a yellow "Stay Alert" (REQ-SURF-010), but it sits in a
  separate card below the hero, away from the status it explains.

## Goal

Under the status the phone shows at most one line that says why the status is what it is, and
nothing that repeats the map.

## Acceptance criteria

- **AC-1** Stay Alert, or No Alert with a neighbouring region under alert (REQ-SURF-005): the hero
  shows one reason line "Alert nearby: <names>" under the region, with the names of
  `NearbyAlertsLine.names` (the CarPlay nearby line's names and "+N" rule).
- **AC-2** Alert in the current region with a known start (REQ-SURF-014, the response's `changed`):
  the hero shows one reason line "Alert since <time>", the start time in the meta line's time
  format, with the date when the start was on an earlier day than the data's check time. With no
  known start there
  is no reason line. The phone does not name neighbours during the region's own alert (see
  Decisions, D2).
- **AC-3** No Alert with no neighbour under alert, Checking, Error, Region unavailable and no
  snapshot: no reason line.
- **AC-4** The overview card ("Nearby" and "Regions under alert N of 25") is removed from the
  Status tab. The map opens the region list, as today. While the map is hidden (failed to load,
  UI-simplify AC-4), a "Regions under alert" row with a chevron stays as the way to the list,
  without the count.
- **AC-5** The reason line is the hero's secondary text: the meta line's font and colour, no glyph,
  no warning colour (owner, 2026-11-10: calm, built-in look); it wraps rather than truncates at
  accessibility sizes. VoiceOver reads the hero as status, region, reason, update time, in that
  order.
- **AC-6** The reason line reads the same snapshot as the status title, so it never contradicts
  it; while the data is stale (REQ-REFRESH-007) it stays, as the "Nearby" row did, because the
  meta line states the age.
- **AC-7** Every new or changed string exists in English, Ukrainian and Russian
  ("Alert nearby: %@", "Alert since %@").

## Out of scope

- CarPlay, widgets, the Control Center control and the Live Activity: unchanged (REQ-SURF-005's
  CarPlay row stays).
- The stale map raster (`aa02e176`): a separate defect and decision (verify the raster against the
  snapshot, or draw the map from the snapshot).
- An all-clear time on the Status tab: the feed has none for a clear region.

## Decisions

- **D1** The count "N of 25" is dropped rather than moved: the map shows it (owner's Request).
- **D2** During the region's own alert the reason is the alert's start, not the neighbours: the
  driver is already in the most severe state, and one line is the budget. This amends REQ-SURF-005
  for the phone ("whether quiet or in alarm" becomes quiet only); CarPlay keeps the nearby row in
  alarm. Owner confirms at the plan gate.
- **D3** The fallback row of AC-4 exists only while the map is hidden, so the list stays reachable
  without a map.

## Requirements touched

REQ-SURF-005 (phone amendment, D2), REQ-SURF-010 (wording of the Stay Alert explanation),
UI-simplify AC-2 and AC-3 (superseded by AC-1 and AC-4 here).
