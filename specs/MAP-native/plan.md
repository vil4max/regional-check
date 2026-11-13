Base: d439bfc6e7ceb71e13c5701cd4499770337388ca (main after PR #40; first base 7073430, rebased)

# Plan: MAP-native, the Status map drawn by the app from the status data

Spec: `specs/MAP-native/spec.md` (commit `afda1f6`). Skill: `/spec-driven-dev:plan`.
Branch: `MAP-native` from `STATUS-reason` tip `7073430` (PR #40 on auto-merge; the branch is
rebased onto main after it merges). Release: 3.4.0 with STATUS-reason, then `tf-3.4.0-2`.

## Context

Build 131 showed the upstream Ubilling raster (`aa02e176`, an old picture upstream serves
intermittently) under a status that contradicted it. The owner chose to draw the map in the app
(2026-11-13), with calm status colours, Crimea grey as part of Ukraine, the tap opening the list
as today and no "Map updated" caption. The map must fit the screen instead of letterboxing a
1000 × 670 picture.

## Business rules

- R1 Fill per region from `lastSnapshot` — the snapshot the hero uses (spec AC-2):
  `.alarm` → alarm fill, `.quiet` → quiet fill, missing → no-data fill; nil snapshot → every unit
  no-data (AC-4).
- R2 Crimea and Sevastopol: always no-data fill, drawn as Ukraine (owner, D3); the feed's
  Sevastopol key stays ignored (`docs/requirements/region-model.md:5`).
- R3 Colours: `Theme.RedesignColors.statusAlert` (#F07C7C), `statusClear` (#7CC39B) muted,
  neutral grey for no data (`statusNoData` #C6CAD0 muted); thin borders in the card surface
  colour; the current region outlined in `textPrimary` (owner: «Спокойные цвета статуса»).
- R4 Tap anywhere → region list; VoiceOver one button labelled by `mapAccessibilityLabel`
  (`RegionalCheck/Data/MapAccessibilityLabel.swift:6-24`), unchanged (AC-6).
- R5 No map request anywhere (AC-3); REQ-PROVIDER-002's 2 rps rule now covers the status only.
- R6 Attribution: CC BY 3.0 IGO, source State Scientific Production Enterprise "Kartographia" via
  OCHA COD-AB / geoBoundaries (AC-8, D1).

## Acceptance criteria and blast radius

AC-1 27 outlines, each AlertRegion once · AC-2 fills · AC-3 same render, no request · AC-4 no
loading or failure state, fallback row removed · AC-5 framed on Ukraine, fills width, REQ-SURF-013
· AC-6 tap and VoiceOver · AC-7 caption removed · AC-8 attribution · AC-9 small, fast, parsed once
· AC-10 raster removed, docs amended · AC-11 reproducible data.

- **May touch:** `RegionalCheck/Views/MapCardView.swift` (rewritten), `MapViewModel.swift`
  (deleted), `RegionalCheck/Data/MapImageSource.swift` (deleted), new
  `RegionalCheck/Data/UkraineOutlines.swift`, `RegionalCheck/Views/AlertMapShape.swift` (or
  inside the card file), new resource `RegionalCheck/Resources/UkraineOutlines.json`,
  `MapPlaceholder.imageset` (deleted), `StatusView.swift`, `StatusReasonLine.swift`
  (`StatusRegionListRow` removed), `StatusLayout.swift` (aspect source), `AppContainer.swift`
  (map client, pull step, session hook), `RegionalCheckApp.swift` (`endForegroundSession` call),
  `AppContainerFixture.swift` (raster branch out, map-request counter kept), Settings/Details
  attribution row, `Localizable.xcstrings`, tests (raster suites deleted, new suites added,
  scenario and layout tests updated), snapshot baselines, `scripts/map/` (data script and note),
  docs: REQ-PROVIDER-002, ADR 0015, MAP-sync, UI-simplify, STATUS-reason AC-4, `docs/core.md`,
  privacy policy only if it names the map, CHANGELOG, release notes.
- **Must not touch:** `UbillingProvider`, `StatusController` polling, CarPlay, widgets, Control
  Center, Live Activity, `NearbyRegionPolicy`, `AlertRegion` cases.
- **Risk class: normal.** No persisted data or public contract; a bundled data licence (handled
  by AC-8).

## Baseline

`afda1f6` code is identical to `1a715fa` (diff outside specs/docs/release is empty), whose gate
passed: `build/verify/baseline.log`, 610 tests passed, 0 failed.

## Approach

Options for drawing:
1. **SwiftUI `Canvas`** filling projected `Path`s per unit inside the card, aspect from the
   outline bounds. Cost: one view, no new framework; cheap at ~3–5 k points. Counter: Canvas has no
   per-path accessibility (not needed: one button, R4).
2. **MapKit `MKPolygon` overlays.** Cost: tiles, network, map chrome to hide; contradicts "no
   request". Counter: overkill and not calm.
3. **Pre-rendered per-region PNG masks tinted at runtime.** Cost: 27 assets, scaling blur.
   Counter: not "dynamic to the screen".

Agent's lean: **1**. `UkraineOutlines` parses the bundled JSON once (static lazy), projects
lon/lat with an equirectangular projection scaled by cos(48.4°), and exposes `units` and
`aspectRatio`. A pure `AlertMapFill.fill(for:snapshot:)` picks the fill. `AlertMapCard` takes
`snapshot`, `currentRegion`, `onOpenRegionList`; it draws oblasts first, then Kyiv city and
Sevastopol on top, then the current region's outline. `MapViewModel` and the raster go away;
`StatusLayout` reads `UkraineOutlines.aspectRatio`.

Data step (offline, committed output): `scripts/map/build-outlines.sh` downloads the pinned
geoBoundaries gbHumanitarian UKR ADM1 release (Kartographia, CC BY 3.0 IGO), runs
`npx --yes mapshaper@<pinned> -simplify <p>% weighted keep-shapes` on the whole layer (shared
borders stay shared), and a Python step maps `shapeID` → `AlertRegion.apiKey` (Kyiv city and
Kyiv Oblast share the name "Kyivska"; Crimea → `crimea`, Sevastopol → `sevastopol`) and writes
compact JSON with coordinates rounded to 3 decimals. `scripts/map/README.md` records URL,
release, licence, command and output size.

## Files and types

- `RegionalCheck/Data/UkraineOutlines.swift`: `enum MapUnit { case region(AlertRegion), crimea,
  sevastopol }`, `struct Outline { unit; rings: [[CGPoint]] }` (projected, unit square),
  `static let shared`, `aspectRatio`, `outline(for:)`.
- `RegionalCheck/Data/AlertMapFill.swift`: `enum AlertMapFill { alarm, quiet, noData }`,
  `static func fill(for: MapUnit, snapshot: AlertsSnapshot?)`.
- `RegionalCheck/Views/MapCardView.swift`: `AlertMapCard(snapshot:currentRegion:onOpenRegionList:)`
  with `Canvas`, `aspectRatio(UkraineOutlines.shared.aspectRatio, contentMode: .fit)`, the
  existing tap/VoiceOver modifier (`opensRegionList`), no caption, no loading state.
- `RegionalCheck/Resources/UkraineOutlines.json` (generated), `scripts/map/build-outlines.sh`,
  `scripts/map/README.md`.
- Settings/Details: one attribution line under the data source ("Region outlines: Kartographia
  via OCHA, CC BY 3.0 IGO") in en/uk/ru.
- Deleted: `MapImageSource.swift`, `MapViewModel.swift`, `MapPlaceholder.imageset`,
  `MapLoadingShimmer`, `StatusRegionListRow`, `map.fullscreen.loading`, `map.updated` strings, the
  fixture raster and `previewMapImage`, `statusPreviewLoadedMap`.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 | `UkraineOutlinesTests` `MAP-native AC-1 every region has exactly one outline` | 27 units; each of 25 `AlertRegion`s once; `crimea` and `sevastopol` present; Kyiv city ≠ Kyiv Oblast outline; every ring has ≥ 3 points inside the unit square |
| AC-2 | `AlertMapFillTests` `MAP-native AC-2 each region takes its fill from the snapshot` | Kharkiv alarm → `.alarm`; Lviv quiet → `.quiet`; region absent from statuses → `.noData`; Crimea and Sevastopol → `.noData` even with every region in alarm |
| AC-3 | `AppScenarioMapTests` `MAP-native AC-3 the map sends no request` | launch, pull, poll, background/foreground with the fixture → `mapRequestCount == 0`; the card's fills come from `controller.lastSnapshot` (view takes the snapshot, no model in between) |
| AC-4 | `AlertMapFillTests` `… AC-4 no snapshot draws every unit as no data`; snapshot `Status no data` | nil snapshot → all 27 `.noData`; the "Regions under alert" row type is gone (compile-level) |
| AC-5 | `UkraineOutlinesTests` `… AC-5 the frame is Ukraine's bounds` + `StatusLayoutTests` | min x = 0 and max x = 1 over all rings (no band); aspect = projected width / height within 0.5 %; layout tests updated to the new aspect, iPhone 17 and Duo cases still pass |
| AC-6 | existing `mapAccessibilityLabel` tests + snapshot | label from the same snapshot; button trait kept |
| AC-7 | snapshot `Status-*` | no caption under the map |
| AC-8 | `DetailsStringsTests` `MAP-native AC-8 the outline credit exists in every language` | key present in en, uk, ru; Settings snapshot shows it |
| AC-9 | `UkraineOutlinesTests` `… AC-9 the outline data is small and parsed once` | resource size < 100 KB; `shared` returns the same instance |
| AC-10/11 | docs amended; `scripts/map/build-outlines.sh` re-run reproduces the committed JSON byte for byte (manual, recorded in the README) | — |

Snapshots: every Status and Home baseline changes (map drawn); `Map-card-loaded`/`loading`
replaced by `Map card` (fixture snapshot) and `Map card no data`.

## Risks

- Collisions (owner settles in Points to decide):
  1. `docs/decisions/0015-two-tab-phone-ia.md:29-31, 58-64, 72-79` — the inline map is the
     upstream raster; per-region taps rejected for lack of a vector map; map request rules. Amended
     by this spec (no request, drawn map; per-region taps stay in the backlog).
  2. `docs/requirements/aerial-alerts-provider.md:131-136, 154-159` REQ-PROVIDER-002 clause 2 — map
     request triggers. Amended: the app sends no map request; lock refreshed.
  3. `specs/MAP-sync/spec.md:77` "Drawing our own map … out of scope (ADR 0015 keeps the upstream
     raster)" — superseded note.
  4. `specs/UI-simplify/spec.md:32-42` AC-3 caption, AC-4 failed map hidden — superseded notes.
  5. `specs/STATUS-reason/spec.md` AC-4 fallback row — superseded (map never hidden).
  6. `docs/core.md:25, 30, 43` "upstream raster alert map" — updated.
- Data licence: CC BY 3.0 IGO needs the credit in the app (AC-8); geoBoundaries' copy is the 2023
  Kartographia release; admin-1 borders have not changed since.
- Tool: `npx mapshaper` downloads a package into the npm cache; it is not a project dependency and
  runs only in the data script (owner approved, point 1).
- Rendering: Canvas redraws on every snapshot change only; paths are projected once. Accessibility
  sizes: the map keeps its width rules (REQ-SURF-013).
- Snapshot timing: no async load any more, so preview races go away.
- Test host: no network; outlines read from the app bundle (`Bundle.main` in the test host).

## Tasks

## Group 1: data
- [x] T001 Data: `scripts/map/build-outlines.sh` + README; generate `UkraineOutlines.json`.
- [x] T002 Test: `UkraineOutlinesTests` AC-1, AC-5, AC-9.
- [x] T003 Implement: `UkraineOutlines` loader and projection.

## Group 2: fills and card (AC-2, AC-3, AC-4, AC-6, AC-7)
- [x] T004 Test: `AlertMapFillTests`; `AppScenarioMapTests` no-request scenario.
- [x] T005 Implement: `AlertMapFill`, new `AlertMapCard`, `StatusView` wiring, `StatusLayout`
  aspect, remove `StatusRegionListRow`.

## Group 3: remove the raster (AC-10)
- [x] T006 Delete `MapViewModel`, `MapImageSource`, placeholder and shimmer, fixture raster,
  AppContainer map client/pull step/session hook; delete raster test suites; update tests that
  counted map requests to expect zero.

## Group 4: attribution and docs (AC-8, AC-10, AC-11)
- [x] T007 Test + implement: attribution string and Settings row.
- [x] T008 Docs: REQ-PROVIDER-002 (+ lock), ADR 0015 amendment, MAP-sync/UI-simplify/STATUS-reason
  notes, core.md, CHANGELOG, 3.4 release notes and What to Test round 2.
- [x] T009 Snapshots re-recorded; live run-sim screenshot; App Store screenshots 02–05 recaptured
  and replaced in ASC.

## Review lows

- low (review round 1): the first-draw `os_signpost` measurement promised by the critic fix was
  not done; AC-9's "no visible delay" rests on the live run-sim screenshot only.
- low (review round 1): DEBUG `applyScreenshotFixture` forces the phase but not `lastSnapshot`,
  so `-ScreenshotPhase alertActive` can draw a map from another snapshot; App Store screenshots
  use `-ScreenshotPhase live` and are not affected.
- low (review round 1): red or mutant runs exist for `AlertMapFillTests` only, not for
  `UkraineOutlinesTests`, the AC-3 scenario or the AC-8 strings test.
- Fixed in the repair round: `showsMap` removed, stale comments and docs updated (both lows).
- low (review round 2): two glass-fill tests were deleted with the dead `RedesignGlass` (owner's
  dead-code request; nothing in production called it); the licence and AC-11 tests have no red run.
  Fixed after round 2: the `awaitStatusSettled` doc, the ThemeRedesignTests header and the round 2
  What to Test line.

## Critic fixes folded in

- `mapAccessibilityLabel` tests move to a new `MapAccessibilityLabelTests` suite before T006
  deletes `MapImageSourceTests` and `MapViewModelSyncTests`; the card's label comes from a pure
  `AlertMapCard.accessibilityText(snapshot:)` that the view uses on its one button element, and a
  test checks it equals `mapAccessibilityLabel` for the same snapshot (AC-6).
- T008 also amends `docs/requirements/surfaces-and-pro-gating.md:15`,
  `docs/requirements/refresh-policy.md:153`, `docs/requirements/aerial-alerts-provider.md:50`,
  `docs/engineering/project-map.md:103,122`, `docs/engineering/testing-strategy.md:57,77`, and
  refreshes `.spec-lock.json` for every approved requirement changed.
- Removed catalog keys, named exactly: `map.caption.updated`, `map.fullscreen.loading`,
  `status.regions.title`; `DetailsStringsTests` drops `status.regions.title` from its required list
  and adds removed-key checks for all three. The `Status map failed` preview and its baseline are
  deleted.
- `UkraineOutlines.aspectRatio` is a Swift constant written by the data script and checked by a
  test against the parsed data, so layout never parses JSON; the JSON is parsed once, lazily, at
  the first map draw. A missing or undecodable resource draws no map (empty card frame of the
  constant aspect) and logs one fault; a unit test proves the bundled file decodes. First draw
  time is measured once with an `os_signpost` interval in a DEBUG run on the simulator and recorded
  in the runtime evidence; there is no timing assertion in tests.
- AC-6 stale case: see point 3.

## Points to decide

1. Run the data step with `npx --yes mapshaper@<pinned>` (downloads into the npm cache, no global
   install, not a project dependency). Owner decides.
   - Decision: accepted («Разрешаю»)
2. Use geoBoundaries gbHumanitarian (2023 copy of the same Kartographia data, smaller download)
   rather than the 84 MB HDX v05 zip. Proposed.
   - Decision: accepted
3. Critic: with stale data the hero turns grey but the map would keep live red and green, and the
   caption that gave its age is removed. Proposed: a stale snapshot draws the same fills at reduced
   opacity (dimmed), so the picture is still readable but does not look live; tested in
   `AlertMapFillTests` (stale → dimmed). Owner decides.
   - Decision: accepted («Приглушить»)
4. Critic: label tests would be deleted with the raster suites; no card-level VoiceOver check.
   `fixed in the plan`.
5. Critic: docs list incomplete. `fixed in the plan`.
6. Critic: catalog keys and the map-failed preview not named. `fixed in the plan`.
7. Critic: decode failure and first-draw time unspecified; layout would parse JSON on the main
   thread. `fixed in the plan`.

Points 4–7: - Decision: accepted («Принимаю все»).
