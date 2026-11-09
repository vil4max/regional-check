Base: a230381d8be1e96e4766012c8613b2d6783293b2

# CARPLAY-status-clarity: plan

Spec: `specs/CARPLAY-status-clarity/spec.md`. Branch `claude/carplay-status-clarity`.

## Business rules (read first)

| Rule | Source |
|---|---|
| CarPlay is one free Status screen: status in the title, region row, nearby row only when a neighbour is under alert, location-denied row only when blocked, Refresh the only action | REQ-SURF-006 (`docs/requirements/surfaces-and-pro-gating.md:126-134`) |
| Stale data shows no marker, with its age; a fresh cached status stays after a failed request | REQ-REFRESH-007 (`docs/requirements/refresh-policy.md:177-185`) |
| "Stay Alert" yellow replaces "No Alert" when a quiet region is surrounded | REQ-SURF-010 |
| Nearby row only when something is nearby | REQ-SURF-005 |
| Owner: too many words, no understanding at one glance | owner, 2026-11-09 (spec Request) |
| Core: nothing decorative on CarPlay's glanceable path | `docs/core.md:17` |

No rule without a source. The new wording below is the owner's call at this gate.

## Acceptance criteria and blast radius

AC-1..AC-6 of the spec. Blast radius: `RegionalCheck/CarPlay/CarPlayTemplateBuilder.swift`,
`CarPlayHeadline` (`CarPlayLoadState.swift:63`), `Localizable.xcstrings`, `RegionalCheckTests/
CarPlayTemplateBuilderTests.swift`, REQ-SURF-001/-006 text. Must not touch: the phone, widgets,
Live Activity, refresh cycle, `StatusState`, entitlements (`com.apple.developer.carplay-driving-task`).
Risk class: normal.

## Baseline

Commit `241fb72694b0c75dd2cd33dbde7283dd40680331`. `ios-verify --base HEAD`: PASS, 495 tests, 0 failed
(`build/verify/baseline.log`).

## What the screen is today (code facts)

- Title fresh: `🚨 Air Raid Alert` (alarm uses the long form), `🟢 No Alert`, `🟡 Stay Alert`
  (`CarPlayTemplateBuilder.swift:57-75`).
- Row 1: region + `Updated: 14:32`. Row 2 (optional): nearby names, or location denied.
- Stale: title `No Current Data`, row 1 region + `Last update: 14:32`, row 2 `Last status: X` + `Stale`,
  optionally location denied (`:87-105`). This is the wordiest state.
- Button `Refresh` / `Checking…`.

## Approach

Options, neutral order:

- **A. Same information template, fewer words.** Title = marker + short status only
  ("🚨 Alert", "🟢 No Alert", "🟡 Stay Alert"); row 1 = region name only, no update time while the
  data is fresh (the title's marker already means "fresh", REQ-REFRESH-007); stale: title
  "No Current Data", row 1 region + age, no "Last status" row. Cost: ~4 files, small, low risk.
  Counterargument: the template's text stays small, so glanceability improves by removing words,
  not by size; the update time disappears from a fresh screen, so a driver cannot see data age
  until it goes stale.
- **B. Big-image list or grid template.** One large state image (colour, symbol) plus the region.
  Cost: new template, new image rendering, possible entitlement check (driving-task allowed
  templates are unverified), REQ-SURF-006 rewritten, more code on the driver's path.
  Counterargument: core forbids decoration on CarPlay's glanceable path, and the template's
  image size is small, so the gain is uncertain.
- **C. A without removing the time:** only cut words (no "Last status" row, shorter alarm title).
  Cost: smallest. Counterargument: the fresh screen keeps its time line, the one the owner may
  count as "letters".

Agent's lean: **A.** Fewer words is what the owner asked for, and the signal already has a
marker and colour word. B is parked until A is tried on the car.

## Files and types

- `CarPlayTemplateBuilder.swift`: `title` uses the short status form for alarm
  (`state.title`), `freshRows` shows the region with no detail, `staleRows` drops the "Last status"
  row and shows the region with the age only.
- `Localizable.xcstrings`: reuse "Alert Active"/"All Clear" short forms (already en/uk/ru, see
  REQ-SURF-001 table); `driver.status.full.alarm` stays for the phone. No new keys if the
  stale row reuses `driver.status.last_update`.
- Docs: REQ-SURF-001 (CarPlay uses the short form), REQ-SURF-006 (fresh screen: region without
  update time; stale: age), amended with dated notes.

## Tests (`CarPlayTemplateBuilderTests`, Swift Testing)

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 | `REQ-SURF-001 CarPlay alarm title is the short form` | alarm → `🚨 Alert`, not `🚨 Air Raid Alert`; quiet → `🟢 No Alert` |
| AC-2 | `REQ-SURF-006 fresh region row is the region name only` | fresh, region Kyiv → item title `Kyiv`, detail empty |
| AC-3 | `REQ-SURF-006 stale screen has no last-status row` | stale cache → items are region+age only; with location denied → 2 items; no "Stale" word |
| AC-4 | existing `staleCacheShowsNoCurrentDataWithoutMarker` kept; plus loading with no cache → "Updating…" | stale 2× interval + 1 s → no marker; exactly at the threshold → still fresh |
| AC-5 | existing yellow/nearby tests unchanged | surrounded quiet → `🟡 Stay Alert` and nearby row |
| AC-6 | `String Catalog en/uk/ru for CarPlay strings` | every key used by the builder has en, uk and ru values |

An ordered sequence (fresh → stale → refresh) is one test with the injected clock (`freshness(advancedBy:)`).

## Risks

- Collision audit (read-only):

| Source | Behaviour implied | Scope | Decision that stands |
|---|---|---|---|
| `surfaces-and-pro-gating.md:27-35` REQ-SURF-001 | CarPlay title uses the full form "Air Raid Alert" | CarPlay titles | none found for keeping it for alarm; owner decides |
| `surfaces-and-pro-gating.md:126-134` REQ-SURF-006 | row shows region with its update time | CarPlay Status | amended 2026-09-21 ("more air, less text"), direction consistent; time on fresh screen is the open point |
| `refresh-policy.md:177-185` REQ-REFRESH-007 | stale shown "with its age" | CarPlay stale | stands; A keeps the age in the stale state |
| `docs/core.md:17,25` | nothing decorative; "see the status, close" | CarPlay | stands, A adds nothing |
| `surfaces-and-pro-gating.md:226-246` REQ-SURF-010 | CarPlay title shows "Stay Alert" yellow | CarPlay | stands |

- Alarm shown in the short form "Alert" is less explicit than "Air Raid Alert": the owner decides.
- Races/lifecycle: none new; the builder is a pure function of `CarPlayLoadState` and `CarPlayFreshness`.
- Test host: tests build templates only and start no CarPlay session.
- Localization: the stale age string reuses an existing key; check uk/ru plural-free formats.
- Device family/entitlement: unchanged (`carplay-driving-task`).
- Unverified: whether the driving-task entitlement allows list/grid templates (matters only for B).

## Tasks

## Group 1: A glanceable CarPlay Status screen
- [x] T001 Test: `REQ-SURF-001 CarPlay alarm title is the short form` proves AC-1. Files: `RegionalCheckTests/CarPlayTemplateBuilderTests.swift`
- [x] T002 Test: `REQ-SURF-006 fresh region row is the region name only` proves AC-2 and AC-3 (`REQ-SURF-006 stale screen has no last-status row`). Files: `RegionalCheckTests/CarPlayTemplateBuilderTests.swift`
- [x] T003 Test: freshness boundary and loading-without-cache prove AC-4; unchanged yellow/nearby tests prove AC-5. Files: `RegionalCheckTests/CarPlayTemplateBuilderTests.swift`
- [x] T004 Implement: short title, region-only fresh row, stale rows without "Last status". Files: `RegionalCheck/CarPlay/CarPlayTemplateBuilder.swift`
- [x] T005 Test + Implement: String Catalog en/uk/ru check for the strings the builder uses proves AC-6. Files: `RegionalCheckTests/`, `RegionalCheck/Resources/Localizable.xcstrings`

## Group 2: Requirements
- [x] T006 Docs: amend REQ-SURF-001 and REQ-SURF-006 with dated notes; run `scripts/spec-trace.sh`. Files: `docs/requirements/surfaces-and-pro-gating.md`

## Review lows
(filled by implement)

## Verification

`ios-verify` (background, 10-minute timeout), `scripts/spec-trace.sh`, then `ios-verify run-sim`
with `-ScreenshotPhase alertActive` (and `allClear`) to look at the CarPlay screen in the
simulator's CarPlay window, in uk and ru for each state (alarm, no alert, stay alert, no current
data, region unavailable), saved under `.artifacts/` as evidence for AC-6.

## Points to decide

`plan-critic` findings, unchanged, each with my proposed answer:

1. [plan:81] The kept test `staleCacheShowsNoCurrentDataWithoutMarker` checks the "Last known status"
   row (`CarPlayTemplateBuilderTests.swift:103-106`), and tests at `:15-36`, `:61-69`, `:83-91` check
   "Air Raid Alert" and "Updated". The plan must say which are rewritten. Fixed in the plan:
   T001-T003 rewrite exactly those four tests (alarm title, quiet screen, failed-refresh title,
   stale cache), keep their REQ ids in the display names, so `scripts/spec-trace.sh` still cites
   REQ-SURF-001, REQ-SURF-006 and REQ-REFRESH-007.
   - Decision: accepted
2. [StatusStateResolver.swift:10-11] A fresh snapshot can resolve to `.regionUnavailable`
   ("? Region Unavailable", `CarPlayLoadState.swift:69`), which AC-1's four states omit. Fixed in
   the plan: it stays as today (marker "?", its existing title), counts as the "no current data"
   group, and gets its own test in T003.
   - Decision: accepted
3. [plan:66, :79] "No detail" on the fresh row would drop the outside-Ukraine note
   (`CarPlayTemplateBuilder.swift:109-110`). Fixed in the plan: the note stays as the row detail,
   because it changes what the driver should trust; only the update time goes. T002 covers it.
   - Decision: accepted
4. [plan:46-47] Without the "Last status" row, the stale age is a time only, so yesterday's cache
   reads "Last update 14:32" (`CarPlayTemplateBuilder.swift:116`). Proposed answer: a snapshot from
   an earlier day shows its date with the time. Owner decides.
   - Decision: accepted
5. [plan:83, :113] AC-6 checks only that keys have en/uk/ru, not that text fits (ru "Будьте
   внимательны", "Нет актуальных данных", a long region name). Fixed in the plan: Verification adds
   a CarPlay simulator screenshot per state in uk and ru, and AC-6's test also checks the longest
   title length against a literal bound. The screenshots are the evidence; owner decides if that is
   enough.
   - Decision: accepted

Owner's answers at this gate (2026-11-09): approach A; alarm title in the short form "Alert"
(REQ-SURF-001 amended for CarPlay); update time off the fresh screen; points 1, 2, 3, 4, 5 accepted,
point 4 as proposed (an earlier-day snapshot shows its date with the time).
