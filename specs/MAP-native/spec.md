# MAP-native: the Status map is drawn by the app from the status data

Status: draft (owner's answers of 2026-11-13 below; the plan gate approves this text). Ships in
3.4.0 with STATUS-reason; 3.4.0 is held until this lands (owner, 2026-11-13).

## Request

Owner, 2026-11-13, after the stale Ubilling map (`aa02e176`) contradicted the status:

> Если мы рисуем карту сами, то нужно оптимизировать карту, сделать ее более динамической под
> экран. Если она отрисовывается сама, то можно сделать ее красивее, симпатичнее и даже... Хотя
> нет, просто по визуалу ее можно оптимизировать, так как она уже не будет статичной.

> Пиши спецификацию для карты. И потом уже после того, как карта будет новая, это все слить в
> main и подготовить к версии. То есть все правки, которые сейчас есть в плане, должны быть
> сделаны.

Owner's answers (2026-11-13): Crimea — «Часть Украины, серый»; colours — «Спокойные цвета
статуса»; tap — «Как сейчас: список»; the "Map updated" caption — «Убрать».

## Why

- The upstream raster intermittently returns an old picture: 17 single-sample returns of
  `aa02e176` in 159 one-minute samples on 2026-11-12 (dev-bank
  `2026-11-12/drivecheck-map-sync/work/lag.log`), and a cache-busting parameter did not avoid it
  (MAP-sync spec, "the Goal is not met"). On 2026-11-13 the owner saw it in build 131: the map
  showed the east only while the status named Kyiv Oblast and Chernihiv Oblast under alert.
- A map drawn from the same snapshot as the status cannot disagree with it, needs no request, and
  can fit the screen instead of letterboxing a fixed 1000 × 670 picture.

## Goal

The Status tab's map shows exactly the alert picture of the snapshot the status above it shows,
drawn by the app, sized to the screen, with no request of its own.

## Acceptance criteria

- **AC-1** The map is drawn from bundled outlines of Ukraine's 27 first-level units (24 oblasts,
  Kyiv city, the Autonomous Republic of Crimea, Sevastopol), simplified so shared borders stay
  shared (no gaps or overlaps). Each of the 25 `AlertRegion`s maps to exactly one outline.
- **AC-2** Each `AlertRegion` is filled from the snapshot the status uses (`lastSnapshot`): alarm
  in the status alert colour, quiet in a muted status clear colour, no status for that region in a
  neutral no-data colour. Crimea and Sevastopol are drawn as part of Ukraine in the neutral
  no-data colour at all times: the app has no status for them. Borders are thin; the current
  region carries a stronger outline.
- **AC-3** The map changes with every new snapshot in the same render as the status, never shows
  another snapshot's picture, and sends no request. The app requests no `?map=` image anywhere.
- **AC-4** Without a snapshot (first launch, offline before any fetch) the outlines show in the
  no-data colour: no spinner, no shimmer, no placeholder image, no error state. The map is never
  hidden, so the "Regions under alert" fallback row of STATUS-reason AC-4 is removed.
- **AC-5** The map is framed on Ukraine's own bounds: it fills the card's width with no empty bands,
  and its height follows the outline's aspect at that width. REQ-SURF-013 keeps working with this
  aspect (compact hero first, then the map narrows to its minimum width).
- **AC-6** Tapping anywhere on the map opens the region list, as today. VoiceOver reads the map as
  one button whose label names the regions under alert from the same snapshot
  (`mapAccessibilityLabel`).
- **AC-7** The "Map updated <time>" caption is removed: the hero's update time is the map's time.
- **AC-8** The outline source is credited in the app: Settings names the boundary data and its
  licence next to the alert data source, in English, Ukrainian and Russian.
- **AC-9** The bundled outline data is small (target: under 100 KB) and the map draws without a
  visible delay on the oldest supported device class; outlines are parsed once per process.
- **AC-10** The raster pipeline is removed: the map URL and variants, the map's network loading
  and session rules, the placeholder asset and shimmer, and the fixture's raster. Requirements and
  decisions that describe the raster are amended (REQ-PROVIDER-002 clause 2, ADR 0015, MAP-sync,
  UI-simplify AC-3 and AC-4, docs/core.md).
- **AC-11** The outlines are reproducible: a committed script and note name the source dataset,
  its version and download URL, the simplification command and its parameters.

## Out of scope

- Per-region taps (owner: «Как сейчас: список»): stays in the backlog.
- CarPlay, widgets, Control Center and the Live Activity: no map there, unchanged.
- Labels, zoom or pan on the map.
- A status for Crimea or Sevastopol (`AlertRegion` has none; the feed's Sevastopol key stays ignored).

## Decisions

- **D1 Data source.** OCHA COD-AB Ukraine (HDX `cod-ab-ukr`), from Ukraine's State Scientific
  Production Enterprise "Kartographia", licence CC BY 3.0 IGO: Ukraine's own borders (Crimea and
  Sevastopol as Ukrainian units), Kyiv city separate, commercial use with attribution. Rejected:
  Natural Earth (tags Crimea and Sevastopol as Russia), GADM (no commercial redistribution),
  OpenStreetMap extracts (ODbL share-alike on a bundled database).
- **D2 Colours.** The status palette (`Theme.RedesignColors`): alarm `statusAlert`, quiet a muted
  `statusClear`, no data a neutral grey; calm, as the hero and the Live Activity (owner's answer).
- **D3 Crimea.** Part of Ukraine, neutral grey (owner's answer).
- **D4 Caption.** Removed (owner's answer).

## Assumptions

- A simple equirectangular projection scaled by the cosine of Ukraine's middle latitude reads
  correctly at card size; no map projection library is needed.
- Simplification needs a topology-aware tool (mapshaper); running it is an offline, one-time data
  step, not a build step.

## Requirements touched

REQ-PROVIDER-002 (clause 2: the app sends no map request), REQ-SURF-013 (aspect source), ADR 0015
(inline map), MAP-sync (superseded for the map's source), UI-simplify AC-3 and AC-4,
STATUS-reason AC-4 (fallback row removed), docs/core.md (the map is the app's drawing, not
upstream's picture).
