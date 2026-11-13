Base: adc81cfe546465adea7d0aa341370321f1c653eb

# Plan: STATUS-two-states, two statuses everywhere, and a hero that fills the screen

Spec: `specs/STATUS-two-states/spec.md` (commit `adc81cf`), amended at T000 with AC-8 (layout).
Skill: `/spec-driven-dev:plan`. Branch `STATUS-two-states` from main `b06c5e9`. Release: 3.4.0
(not yet submitted), TestFlight round `tf-3.4.0-3`.

## Context

The owner found "Stay Alert" ("Будьте внимательны") in yellow reads as a third alert level and
chose two statuses everywhere: "No Alert" green with the shield, and the neighbours as a note
(«Везде», «Зелёный + пометка»). With the drawn map the Status tab now leaves about 180 pt empty
under the map on a large iPhone; the owner chose «Радар растёт»: the hero ring takes the spare
height.

## Business rules

- R1 A quiet region on fresh data is "No Alert", green, shield — neighbours never change the
  status (spec AC-1, owner D1/D2).
- R2 The note is REQ-SURF-005's neighbour list: phone reason line (STATUS-reason AC-1) and CarPlay
  nearby row unchanged; Siri adds "Alert nearby: …" (spec AC-3, D4); widget and control no note
  (AC-4, D3).
- R3 Alert red, stale/no data grey, region unavailable as today (AC-5).
- R5 All-clear line (new AC-9, owner: «Строка отбоя в 3.4.0», reference: the all-clear screen and
  the Kyiv Digital history he sent): when the app sees the driver's region go from alarm to quiet,
  it records the all-clear time (the check time of the first quiet response) and the duration (from
  the alarm start of REQ-SURF-014). While quiet, with no neighbour under alert, the reason line reads
  "All clear at 11:57 · the alert lasted 49 min" for 30 minutes after the all-clear (point 4); the
  nearby note wins when a neighbour is under alert. No record when the app did not see the
  transition (the feed has no all-clear time). One record per region, kept in the app's defaults,
  never a history list (core "Never").
- R4 Layout (new AC-8): when the hero, its lines and the full-width map leave spare height, the
  hero ring, disc, symbol and ticks scale up by the spare height, capped at 1.6× the design ring
  (156 pt → 250 pt); spare height beyond the cap is split equally above the hero and between the
  hero and the map. The REQ-SURF-013 shrink path (compact hero, narrowed map) is unchanged; AX
  sizes keep the compact ring.

## Acceptance criteria and blast radius

AC-1 green No Alert everywhere · AC-2 phone/CarPlay note unchanged · AC-3 Siri note · AC-4 widget
and control two statuses · AC-5 other states unchanged · AC-6 surrounded rule removed, REQ-SURF-010
retired · AC-7 strings en/uk/ru · AC-8 (new) hero grows into spare height, capped · AC-9 (new)
all-clear line with time and duration, from the app's own observation.

AC-9 also touches `RegionalCheck/Status/StatusController.swift` (record on accepted snapshots) and a
new `RegionalCheck/Status/AllClearRecord.swift`; it stores one small record per region in the app's
`UserDefaults` (no migration: absent means no line).

- **May touch:** `Packages/DriveCheckKit/Sources/DriveCheckKit/{NearbyRegionPolicy,StatusPresentation,
  WidgetTimelineBuilder,ControlStatusValueBuilder,DriveCheckActivityAttributes (WidgetPresentationAccent),
  AlertStatusAnswerBuilder,DriveCheckColors}.swift`, the package catalog (Siri note keys),
  `RegionalCheck/{Status/StatusController+Presentation,CarPlay/CarPlayTemplateBuilder,App/Theme+Redesign,
  Views/StatusHeroCard,Views/StatusHeroGraphic,Views/StatusLayout,Views/StatusView,Views/StatusReasonLine}.swift`,
  `RegionalCheckWidgets/DriveCheckWidgetTokens.swift`, the three `Localizable.xcstrings`, tests
  listed below, snapshot baselines, docs (REQ-SURF-010 retired, REQ-SURF-011, REQ-SURF-013, surface
  table, refresh-policy.md:72, architecture docs, states.md, README.md:16, CHANGELOG, 3.4 notes,
  screenshot 03), `.spec-lock.json`.
- **Must not touch:** the Live Activity, the map fills, `NearbyRegionPolicy.activeAlerts`,
  `StatusController` polling, CarPlay layout beyond the title.
- **Risk class: normal.**

## Baseline

`b06c5e9` code is identical to `a5663c9`, whose gate passed: `build/verify/baseline.log`, 580 tests,
0 failed.

## Approach

One approach for statuses: delete the caution path at its source. `NearbyRegionPolicy.isSurrounded`,
`StatusPresentation.isSurrounded/isCaution/caution*`, `WidgetStatusPresentation.isCaution`,
`WidgetPresentationAccent.caution`, `RedesignStatusAccent.caution`, the CarPlay "🟡" branch and the
three `status.caution.title` keys go; every switch loses its caution case, so the compiler finds
each surface. Siri: move the neighbour-names rule into DriveCheckKit (`NearbyAlertsLine.names` is
app-only today) as `NearbyAlertsNames.names(_:locale:)` using `AlertRegion.title(locale:)`, add
package keys `intent.answer.nearby` ("Alert nearby: %@") and a "+N" key, and append the note to
`full` and `supporting` the way the age suffix is appended (`AlertStatusAnswerBuilder.swift:118-130`);
the app's `NearbyAlertsLine` delegates to it so the phone, CarPlay and Siri share one names rule.
`statusStale` (yellow) stays: `LocationAccessDeniedCard` uses it; its "caution" comment is fixed.

One approach for layout: `StatusLayout.resolve` gains a `heroScale` output (1 when nothing to
spare or on the shrink path; up to 1.6 with spare height) and a `spareGap`; `StatusHeroGraphic`
takes a `scale` multiplying its ring, disc, symbol and tick sizes; `StatusView` applies the gap
above the hero and before the map. Pure function, tested with literal screen sizes.

## Files and types

- Package: `NearbyAlertsNames` (new, in `NearbyRegionPolicy.swift` or its own file);
  `AlertStatusAnswerBuilder` note; removals listed above.
- App: `NearbyAlertsLine.names` → package call; `StatusLayout` (`heroScale`, `spareGap`),
  `StatusHeroGraphic(scale:)`, `StatusHeroCard` passes it, `StatusView` wiring.
- Strings: remove `status.caution.title` ×3; add package `intent.answer.nearby`,
  `intent.answer.nearby_more` in en/uk/ru.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 | `StatusPresentationTests` rows updated; new `TwoStatesTests` `STATUS-two-states AC-1 a quiet region is No Alert whatever its neighbours do` | Kyiv city with Kyiv Oblast in alarm (old Kyiv rule) → phone accent `.clear`, title "All Clear" key, shield; Poltava with 5/7 neighbours → same; widget accent `.clear`; control accent `.clear`; CarPlay title "No Alert" without "🟡" |
| AC-2 | existing `StatusReasonLineTests`, `CarPlayTemplateBuilderTests` nearby row | unchanged and green |
| AC-3 | `AlertStatusAnswerBuilderTests` `STATUS-two-states AC-3 Siri says No Alert and names the neighbours` | quiet + 2 neighbours → status "No Alert", full and supporting contain "Alert nearby: A, B"; quiet + 4 → "+2"; quiet + none → no note; alarm → no note; stale quiet with neighbours → age suffix and note both present |
| AC-4 | `WidgetTimelineBuilderTests`, `ControlStatusValueBuilderTests` | surrounded snapshot → `.clear`, shield, no extra text |
| AC-5 | existing alarm/stale/unavailable rows | unchanged |
| AC-6 | `SurroundedStatusTests` deleted; REQ-SURF-010 tests re-pointed (`WidgetPresentationAccentTests:24`, `ControlStatusValueBuilderTests:35,52`, `WidgetTimelineBuilderTests:74`) | `spec_trace.py lock --write`; trace still 100 % of active requirements |
| AC-7 | `DetailsStringsTests`-style catalog test in the package or app | `status.caution.title` absent from all three catalogs; new Siri keys in en/uk/ru with `%@` |
| AC-8 | `StatusLayoutTests` `STATUS-two-states AC-8 the hero grows into spare height` | iPhone 17 Pro Max portrait (spare ≈ 180 pt) → scale 1.6 capped, positive gap; iPhone 17 where it just fits → scale ≈ 1 + spare/156; no spare → 1.0, gap 0; Duo landscape (shrink path) → compact, scale 1; accessibility size → compact, scale 1 |

Snapshots: `Status-stay-alert` becomes the green "No Alert" with the note (preview renamed
"Status alert nearby"); every Status baseline changes with the grown hero.

## Risks

- Collisions:
  1. `docs/requirements/surfaces-and-pro-gating.md:258-298` REQ-SURF-010 approved, owner-amended
     2026-09-22/23 (Kyiv rule) — retired by the owner's 2026-11-13 answers.
  2. `:313` REQ-SURF-011 clause 2 lists "Stay Alert" — amended (status list and the note).
  3. `:353-366` REQ-SURF-013 "where everything fits, the hero and the full-width map keep their design
     sizes" — amended by AC-8 (owner: «Радар растёт»).
  4. `specs/CARPLAY-status-clarity/spec.md:22,30-31`, `specs/STATUS-reason/spec.md` (Stay Alert
     wording) — historical; superseded notes only.
  5. App Store screenshot 03 is the yellow state — recaptured.
- The Kyiv-city "oblast alone" rule disappears with `isSurrounded`; the note still names Kyiv Oblast
  (REQ-SURF-005's wider ring), so nothing the driver saw is lost.
- Siri strings live in the package catalog; the app catalog keeps its own nearby keys.
- Hero scale and the cold-start overlay: `ColdStartHeroView` keeps design sizes; the hand-off frame
  must match the scaled hero or the overlay jumps — check in the simulator (risk to verify, not to
  design around).

## Tasks

## Group 0: docs
- [x] T000 Spec: add AC-8 (owner: «Радар растёт») and AC-9 (owner: «Строка отбоя в 3.4.0», his two
  reference screenshots); retire REQ-SURF-010; amend REQ-SURF-011,
  REQ-SURF-013, the surface table; `lock --write`.

## Group 1: two statuses (AC-1, AC-4, AC-5, AC-6)
- [x] T001 Test: `TwoStatesTests`, updated presentation/widget/control/CarPlay tests.
- [x] T002 Implement: remove the caution path in the package, app and widgets.

## Group 2: Siri note (AC-3, AC-7)
- [x] T003 Test: `AlertStatusAnswerBuilderTests` AC-3 cases; catalog test.
- [x] T004 Implement: `NearbyAlertsNames`, Siri note, keys; app `NearbyAlertsLine` delegates.

## Group 3: hero fills the screen (AC-8)
- [x] T005 Test: `StatusLayoutTests` AC-8 cases.
- [x] T006 Implement: `heroScale`, `spareGap`, `StatusHeroGraphic(scale:)`, wiring; cold-start check.

## Group 3b: all-clear line (AC-9)
- [x] T006a Test: `AllClearLineTests` — alarm→quiet records time and duration; quiet→quiet keeps
  it; a new alarm clears it; no record without an observed alarm; line shown within 30 min, hidden at 30 min and after;
  nearby note wins; region change shows only that region's record; strings en/uk/ru.
- [x] T006b Implement: `AllClearRecord` (pure), recorded by `StatusController` on accepted snapshots,
  stored per region in the app's defaults; `StatusReasonLine` quiet branch; strings.

## Group 4: evidence and release
- [x] T007 Snapshots, docs and CHANGELOG, 3.4 notes and What's New, screenshot 03 recaptured.

## Review lows
(filled by implement)

## Points to decide

1. Spec D3: widget and Control Center show no note. Proposed.
2. Spec D4: Siri adds "Alert nearby: …" in words. Proposed.
3. AC-8 cap 1.6× (ring 250 pt) and the leftover split above the hero and before the map. Proposed.
4. AC-9: how long the all-clear line stays — 2 hours after the all-clear. Proposed; owner decides.
   - Decision: 30 minutes («30 минут»)
5. AC-9 source: the app's own observation, not Kyiv Digital (a Kyiv-only web page with no API or
   licence). Proposed. A "today" history list like Kyiv Digital's: owner «Не нужно» — out of scope.
6. Critic: the Details/AI summary (`StatusDetailsProvider.swift:123`, `CountrySummaryValidation.swift:34-46`,
   keys `status.details.nearby_alerts(_more)`) still says «Будьте внимательны». Proposed: it moves to
   the "Alert nearby" wording in en/uk/ru, validator and prompt included, with tests (Group 1).
   `fixed in the plan`.
7. Critic: with location denied, CarPlay shows the location row instead of the nearby row, so the
   driver loses the neighbour signal once yellow goes. Proposed: CarPlay shows both rows (template
   allows 10; the screen uses at most 4), with a test. `fixed in the plan`.
8. Critic: the grown hero feeds back into the measured height. Proposed: the measurement reports the
   design-size height (subtract the ring growth and the gaps), and an AC-8 test feeds a grown
   measurement back in and gets the same answer. `fixed in the plan`.
9. Critic: the reason line or the location card appearing would resize the ring on a poll.
   Proposed: the spare height is computed with room for one reason line always reserved, so the line
   coming or going never resizes the ring; the rare location card may resize it. AC-8 test with and
   without the line. `fixed in the plan`.
10. Critic: two "+N" keys. Proposed: the package owns the names rule and its "+N" key; the app's
    `driver.status.nearby_names_more` is removed in en/uk/ru; the app passes `Locale.current`.
    `fixed in the plan`.

Points 1–3 and 5–10: - Decision: accepted («Принимаю все»).
