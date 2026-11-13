Base: 20157a1a2d4d39036384148dde737a4798855210

# Plan: STATUS-reason, one reason line under the status instead of the overview rows

Spec: `specs/STATUS-reason/spec.md` (commit `20157a1`). Skill: `/spec-driven-dev:plan`.
Branch: `STATUS-reason` from main `1d3845e`. Release: 3.5.0, together with MAP-native (next spec).

## Context

In build 3.4.0 (131) the owner saw "Stay Alert", "Nearby: Kyiv Oblast, Chernihiv Oblast +2",
"Regions under alert 13 of 25" and a map with only the east in red, and judged both rows useless
next to the map (2026-11-13). Investigation: the rows were right; the map was upstream's stale
raster `aa02e176` (separate defect, MAP-native). The owner chose «Причина в подзаголовок»: drop
the card, show one reason line in the hero, open the list from the map.

## Business rules

- R1 Nearby names and "+N" rule: `NearbyAlertsLine.names` (REQ-SURF-005, CarPlay's line).
- R2 Stay Alert is quiet + surrounded (REQ-SURF-010, `StatusPresentation.isCaution`); the reason
  line gates on phase `.quiet` + non-empty nearby, so plain No Alert with a neighbour shows it too
  (spec AC-1) and stale data keeps it (AC-6).
- R3 Alert start is the response's `changed` for the region (REQ-SURF-014,
  `StatusController.alarmStartedAt`); unknown start → no line (AC-2).
- R4 Time format: the meta line's `time: .shortened` (device locale and 12/24-hour setting), with
  day and abbreviated month when the start is on an earlier day than the data's check time
  (`state.checkedAt`) — CarPlay's existing rule (`CarPlayTemplateBuilder.swift:104-115`). The
  reference is the check time, not the wall clock: deterministic in fixtures, and it moves with
  every refresh; across midnight with failing refreshes the meta line already says the data is old.
- R5 Calm look: secondary text style, no glyph, no warning colour (owner, 2026-11-10).

## Acceptance criteria and blast radius

AC-1 nearby reason · AC-2 alert-since reason · AC-3 no reason otherwise · AC-4 card removed, map
opens the list, fallback row while the map is hidden · AC-5 style and VoiceOver order · AC-6 same
snapshot, kept while stale · AC-7 en/uk/ru strings.

- **May touch:** `RegionalCheck/Views/StatusNearbyLine.swift` (becomes `StatusReasonLine` +
  fallback row), `StatusHeroCard.swift`, `StatusView.swift`, `MapCardView.swift` (doc comment),
  `RegionalCheck/CarPlay/CarPlayTemplateBuilder.swift` (use the shared time helper, no behaviour
  change), new `RegionalCheck/Data/DayAwareTime.swift`, `Localizable.xcstrings`, tests
  `StatusNearbyLineTests.swift` → `StatusReasonLineTests.swift`, `DetailsStringsTests.swift`,
  `StatusLayoutTests.swift` (comment), snapshot baselines, `docs/requirements/surfaces-and-pro-gating.md`
  + `.spec-lock.json`, `specs/UI-simplify/spec.md` (supersede notes), `CHANGELOG.md`.
- **Must not touch:** CarPlay output, widgets, Control Center, Live Activity, `NearbyRegionPolicy`,
  `MapViewModel` loading, `StatusController` polling.
- **Risk class: normal.** No persisted data or public contract.

## Baseline

`1d3845e` code is identical to `b015039` (`git diff --stat b015039 1d3845e -- . ':!docs' ':!specs'`
empty), whose `ios-verify` gate passed: `build/verify/baseline.log`, 665 test cases passed, 0 failed.

## Approach

One approach: a pure `StatusReasonLine.text(region:phase:snapshot:alarmStartedAt:checkedAt:)` beside
the existing `StatusNearbyLine` logic decides the line; `StatusHeroCard` gains an optional
`reasonText` rendered between the region row and the meta line and spoken between them;
`StatusView` drops `StatusOverviewRows` and shows a chevron row "Regions under alert" only while
`mapViewModel.loadFailed` (the expression `StatusView.swift:36` already uses). CarPlay's private
same-day time rule moves to a shared `DayAwareTime.text(_:reference:)` used by both (CarPlay
passes its `now`, the phone passes `checkedAt`).

Fixtures for evidence: the fixture snapshot gets an alarm start for its alarm regions
(`AppContainerFixture.swift:141-151`), and `StatusView` gains a "Status stay alert" preview (Kyiv
city with Kyiv Oblast under alert) and a "since" case at AX5, so the snapshot baselines show both
reason lines. Runtime evidence is these rendered baselines plus one `ios-verify run-sim` screenshot
with live data, labelled as live; the screenshot fixture phases are not extended.

## Files and types

- `RegionalCheck/Data/DayAwareTime.swift` (new): `static func text(_ date: Date, reference: Date) -> String`.
- `RegionalCheck/Views/StatusNearbyLine.swift` → `StatusReasonLine.swift`: `StatusReasonLine`
  (replaces `StatusNearbyLine`, `StatusRegionsCount`), `StatusRegionListRow` (replaces
  `StatusOverviewRows`, title + chevron, no value).
- `StatusHeroCard.swift`: `var reasonText: String?`; a11y label "title, region, reason, meta"
  through a pure `static func accessibilityText(...)` so a unit test can check the order.
- `StatusView.swift`: pass `reasonText`, fallback row, doc and preview comments.
- `CarPlayTemplateBuilder.swift`: `staleDetail` calls `DayAwareTime.text`.
- Strings: new `status.reason.nearby` "Alert nearby: %@" / «Тривога поруч: %@» / «Тревога рядом: %@»,
  `status.reason.since` "Alert since %@" / «Тривога з %@» / «Тревога с %@»; remove the unused
  `status.nearby.title`, `status.regions.count`; keep `status.regions.title`.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 | `StatusReasonLineTests` `REQ-SURF-005 STATUS-reason AC-1 a quiet region with neighbours under alert names them` | quiet + Kyiv Oblast, Chernihiv, +2 → "Alert nearby: Kyiv Oblast, Chernihiv Oblast +2" (NearbyAlertsLine's string); quiet + 1 neighbour (not surrounded) → line shown; quiet + no neighbour → nil |
| AC-2 | `… AC-2 an alert shows its start` | alarm + start 12:05 today → "Alert since 12:05"; start yesterday 23:50 → day and month included; alarm + nil start → nil; alarm + neighbours under alert → still "since", no names |
| AC-3 | `… AC-3 no reason in other phases` | checking, error, regionUnavailable, idle, nil snapshot → nil |
| AC-4 | `StatusRegionListRowTests` / view-model level: `… AC-4 the list row shows only while the map is hidden` | map loaded → no row; `loadFailed` → row; snapshot baselines `Status-*`, `Home-*`, `Main-tabs` re-recorded without the card |
| AC-5 | `StatusHeroCardTests` `… AC-5 VoiceOver reads status, region, reason, time` | with reason → "Stay Alert, Kyiv, Alert nearby: …, Updated 12:38"; without → no empty comma slot; AX5 snapshot shows the line wrapped |
| AC-6 | `… AC-6 stale data keeps the reason` | quiet stale snapshot with neighbours → "Alert nearby" shown (phase-gated, not accent-gated); stale alarm with a known start → "Alert since" shown (the phone differs from the Live Activity, which shows a start only for a fresh alarm, REQ-SURF-014 — on purpose: the meta line states the age) |
| AC-7 | `DetailsStringsTests` updated | both new keys have en, uk, ru; removed keys absent |
| R4 | `DayAwareTimeTests` + existing `CarPlayTemplateBuilderTests` | locale `en_US_POSIX`-independent: expected strings built with the same formatter, time zone pinned (pattern of `CarPlayStaleScreenTests.swift:16-17`); start same day as check → time only; start the day before → day and month present; CarPlay tests unchanged and green |

## Risks

- Collisions (owner settles in Points to decide):
  1. `docs/requirements/surfaces-and-pro-gating.md:117-121` REQ-SURF-005 "whether quiet or in
     alarm … On the phone the line is its own row" — amended by D2 (phone: quiet only, in the
     hero); `.spec-lock.json:267` refreshed with `lock --write`. None found confirming the alarm
     case after 2026-09-21.
  2. `specs/UI-simplify/spec.md:29-33` AC-2/AC-3 (Nearby row, "N of 25" row) — supersede notes.
  3. `specs/DETAILS-compact/spec.md:46` "nearby signal stays on Status as its own row";
     `specs/DUO-iphone-duo/spec.md:20` "the nearby line"; `specs/MAP-sync/spec.md:27` "the
     'Regions under alert' row"; `MapCardView.swift:12-13` — historical specs keep their text,
     the code comment is updated.
  4. `docs/decisions/0015-two-tab-phone-ia.md:122-135` rejects moving nearby off Status — kept: the
     line stays on Status.
  5. REQ-SURF-013 compact hero (`:353`): no numeric budget; `StatusLayout` measures the height
     above the map, so one extra wrapped line is absorbed (check Status-AX5 and SE-size snapshots).
- Localization: three languages, `%@` arguments; Ukrainian «о» vs «з» for time — «Тривога з 12:05».
- Snapshots must be re-recorded on the worktree tests simulator (Snapshots plan).
- Test host: pure functions, no live services.

## Tasks

## Group 1: requirements
- [ ] T000 Docs: amend REQ-SURF-005 (phone reason line, quiet only) and note REQ-SURF-010
  wording; UI-simplify AC-2/AC-3 supersede notes; `spec_trace.py lock --write`.

## Group 2: reason line (AC-1, AC-2, AC-3, AC-6, R4)
- [ ] T001 Test: `DayAwareTimeTests`, `StatusReasonLineTests` AC-1/2/3/6. Files: `RegionalCheckTests/`
- [ ] T002 Implement: `DayAwareTime`, `StatusReasonLine`; CarPlay uses `DayAwareTime`.

## Group 3: hero and card (AC-4, AC-5, AC-7)
- [ ] T003 Test: hero a11y order, list-row visibility, strings. Files: `RegionalCheckTests/`
- [ ] T004 Implement: `StatusHeroCard.reasonText`, `StatusView` wiring, `StatusRegionListRow`,
  strings, comments.
- [ ] T005 Fixture alarm start, "Status stay alert" preview, AX5 "since" case; snapshots
  re-recorded; CHANGELOG 3.5.0 line; baselines copied and one live `run-sim` screenshot in
  `build/review/runtime/`.

## Review lows
(filled by implement)

## Points to decide

1. Spec D2: during the region's own alert the phone shows "Alert since …", not the neighbours
   (REQ-SURF-005 amended for the phone; CarPlay unchanged). Owner decides.
   - Decision: accepted
2. 3.4.0 (build 131, ready to submit) keeps the upstream stale-raster risk that exists since 3.2;
   the fix is MAP-native in 3.5.0. Proposed: submit 3.4.0 as is. Owner decides.
   - Decision: declined — hold 3.4.0 until the new map («Держать до 3.5.0»). Consequence: 3.4.0
     was never submitted, so the combined release may keep the number 3.4.0 (ASC draft, screenshots
     and What's New already there; TestFlight round `tf-3.4.0-2`) or move to 3.5.0. Agent's lean:
     keep 3.4.0; asked in the report, not decided here.
3. STATUS-reason ships in 3.5.0 with MAP-native (one feature release). Proposed.
   - Decision: accepted (one release with MAP-native; its number per point 2)
4. Critic: `now` has no source in the view; the fixture clock is fixed in 2026-09. Proposed: the
   earlier-day check uses the data's check time (R4). `fixed in the plan`.
5. Critic: no fixture or preview can show either reason line. Proposed: alarm start in the fixture
   snapshot, a Stay Alert preview, an AX5 "since" case (Approach). `fixed in the plan`.
6. Critic: spec AC-2 says "24-hour" but the meta line follows the device setting; tests expected
   fixed strings. Proposed: follow the device setting like the meta line (spec AC-2 wording
   corrected after approval to "the meta line's time format"); tests build expected strings with
   the formatter. `fixed in the plan`.
7. Critic: T005 screenshots had no deterministic source. Proposed: rendered snapshot baselines as
   evidence plus one live run-sim screenshot labelled live; no new fixture phases. `fixed in the plan`.
8. Critic: AC-6 tested only "Alert nearby". Proposed: add a stale alarm with a known start, which
   keeps "Alert since" on the phone on purpose. `fixed in the plan`.

Points 4–8: - Decision: accepted («Принимаю все»).
