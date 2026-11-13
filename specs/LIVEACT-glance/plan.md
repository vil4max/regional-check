Base: ba76f388279fc6607f1acfe59a845679a3176324

# Plan: LIVEACT-glance, a Live Activity readable at one glance (3.4.0)

Spec: `specs/LIVEACT-glance/spec.md`. Skill: `/spec-driven-dev:plan`.

## Context

The owner asked to improve the Live Activity and chose all seven criteria of LIVEACT-glance
(2026-11-12): the CarPlay and Watch `.small` view, an alert-duration timer, the Dynamic Island,
accessibility, localization and StandBy, with SF Symbols as markers. The Live Activity now also
appears on the CarPlay Dashboard and the Mac by itself (iOS 26). The aim: one glance tells the
state of the driver's region, in every place the activity is shown.

## Business rules

- R1 Short status words in the Live Activity and Dynamic Island (`surfaces-and-pro-gating.md:40`).
- R2 A stale alarm stays red and says "May be outdated" (REQ-SURF-003); a stale non-alarm shows
  the grey clock badge and "Last known: {status}" (states.md row 9).
- R3 Every state differs by shape, not only colour, on the Lock Screen, Dynamic Island, Watch and
  Mac (ALERT-push AC-10).
- R4 Refresh sits on the Lock Screen and the expanded island (REQ-SURF-009); CarPlay disables
  buttons, so the `.small` view has none (Apple, Displaying live data).
- R5 Matrix row: phase, region, time, stale marker, no source name
  (`surfaces-and-pro-gating.md:19`). **The timer adds a field to this row** (point 1).
- R6 Timer start = the time the server first saw the alarm, at most one 30 s poll late; none after a
  gap or a cold start (spec AC-2, owner 2026-11-12).
- R7 Calm, native: Apple's own components and wording (owner memory "calm, native iOS").

## Acceptance criteria and blast radius

AC-1 `.small` · AC-2 timer · AC-3 SF Symbol markers · AC-4 Dynamic Island · AC-5 VoiceOver and
Dynamic Type · AC-6 en/uk/ru, long region names · AC-7 StandBy.

- **May touch:** `RegionalCheckWidgets/DriveCheckLiveActivity.swift` (split into view files),
  `Packages/DriveCheckKit/Sources/DriveCheckKit/DriveCheckActivityAttributes.swift` (one optional
  field), `RegionalCheck/LiveActivity/LiveActivityController.swift` (carry the field),
  `RegionalCheckWidgets/Localizable.xcstrings`, previews, tests; drivecheck-api
  `src/push/liveActivity.ts` and `src/push/alarm.ts` (the start time, its own PR).
- **Must not touch:** phone, widgets, CarPlay screen (CARPLAY-glance), Siri, the lifecycle policy.
- **Risk class: high.** `ContentState` is a public contract with the live server's pushes.

## Baseline

Commit `6bd22c1` (docs/3.4.0-specs on main `5ac410c`). `ios-verify --base HEAD`: PASS, 568 tests
(`build/verify/baseline.log`).

## Approach

One approach: keep `ActivityConfiguration` and the presentation struct, split the views by place
(Lock Screen, `.small`, island regions, StandBy) into small files, and add one optional
`alertStartedAt: Date?` to `ContentState`. Optional means old pushes and old apps decode as today
(no timer), and a new app decodes old pushes. The server sets it on `start` and keeps it on every
`update`; the app keeps the value it last saw and never invents one for an activity it starts
itself unless point 2 says so. The timer is `Text(.currentDate, format: .reference(to: start,
allowedFields: [.hour, .minute]))` (iOS 18+, "Started 12 min ago"), which the system advances
without pushes; no seconds (R7, point 5). A stale alarm hides it (point 3).

## Files and types

- `DriveCheckActivityAttributes.swift`: `ContentState.alertStartedAt: Date?` (decodes when absent).
- `RegionalCheckWidgets/LiveActivity/` (new folder): `LockScreenView.swift`, `SmallView.swift`,
  `IslandRegions.swift`, `StandByView.swift`, `LiveActivityPresentation.swift` (moved, adds
  `accessibilityText` and `startedAt`).
- `LiveActivityController.swift`: carry `alertStartedAt` from the activity's content into updates.
- drivecheck-api: `startedAt` per region in the alarm state, `alertStartedAt` in `start`/`update`
  content-state.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-2 contract | `DriveCheckKitTests`: `REQ-SURF-014 ContentState decodes the server's JSON with and without alertStartedAt` | server JSON of 3.3 (no key) → `nil`; with `816175714` → that date; app encodes → server field names unchanged |
| AC-2 keep | `LiveActivityControllerTests`: `REQ-SURF-014 an update keeps the server's alert start` | activity content has a start, the app updates `checkedAt` → start unchanged; an all-clear end → no start |
| AC-2 server | drivecheck-api `REQ-PUSHAPI-015 start and update carry the alert start` | confirmed alarm at T → `start` and later `update` carry T; alarm after a gap → no field |
| AC-1, AC-3, AC-4, AC-7 | `LiveActivityPresentationTests`: per state (alarm, quiet, stale alarm, stale quiet, checking) the symbol, colour and words for each place | stale alarm keeps red and the alarm symbol; checking never shows a timer; minimal shows the timer only in a fresh alarm with a start |
| AC-5 | `REQ-SURF-014 the Live Activity reads as one sentence` | alarm + start → "Air raid alert, Kyiv, for 12 minutes"; stale → includes "may be outdated"; no start → no duration |
| AC-6 | String Catalog test: every new key has en, uk, ru; the longest region name truncates with "…" in compact trailing (preview check, manual) | missing uk → fails |
| AC-1, AC-4, AC-7 visual | previews for `.small`, compact, minimal, expanded, StandBy in five states; screenshots in CarPlay Simulator (240×78, 170×78) | manual, recorded in `.artifacts/` |

## Risks

- Contract: an unknown key in an old app's decoder is ignored (synthesized `Codable`); a missing key
  decodes to `nil`. Proven by the AC-2 contract test before the server change ships.
- Collisions: (1) matrix row `surfaces-and-pro-gating.md:19` has no duration: amend it (point 1).
  (2) ALERT-push AC-10, shape per state, against AC-4's timer in the minimal view: a timer is text,
  not a shape (point 4). (3) states.md row 9, compact trailing is the region name: kept.
- Snapshot tests do not cover widgets (Prefire covers `RegionalCheck/Views` only): visual checks
  are previews plus manual simulator screenshots.
- Test host: tests build presentations only; no ActivityKit request.

## Tasks

## Group 1: contract and timer data (AC-2)
- [x] T000 Docs: add REQ-SURF-014 (the Live Activity's glance content: duration, accessibility sentence, places) as `proposed` to `docs/requirements/surfaces-and-pro-gating.md`, amend the matrix row (point 1), so the trace knows the id before tests cite it.
- [x] T001 Test: ContentState decode with and without `alertStartedAt`. Files: `Packages/DriveCheckKit/Tests/DriveCheckKitTests/ActivityContentStateTests.swift`
- [x] T002 Implement: the optional field. Files: `DriveCheckActivityAttributes.swift`
- [x] T003 Test: an update keeps the server's start. Files: `RegionalCheckTests/LiveActivityControllerTests.swift`
- [x] T004 Implement: carry the start in the controller. Files: `LiveActivityController.swift`

## Group 2: presentation per place (AC-1, AC-3, AC-4, AC-5, AC-7)
- [ ] T005 Test: presentation per state and place, accessibility sentence. Files: `RegionalCheckTests/LiveActivityPresentationTests.swift`
- [ ] T006 Implement: move the presentation into `RegionalCheckWidgets/LiveActivity/`, add the sentence and duration; widget target membership for the test.
- [ ] T007 Implement: `.small`, island regions, StandBy views; previews for every place and state.

## Group 3: strings (AC-6)
- [ ] T008 Test: catalog keys complete in en/uk/ru. Files: `RegionalCheckTests/StringCatalogTests.swift` (extend if it exists)
- [ ] T009 Implement: new keys ("for %@", accessibility phrases) in three languages.

## Group 4: server start time (AC-2, drivecheck-api, its own PR; deploy is the owner's)
- [ ] T010 Test: `REQ-PUSHAPI-015`. Files: `tests/pushAlertStart.test.ts`
- [ ] T011 Implement: `startedAt` per region, the field in `start`/`update`. Files: `src/push/alarm.ts`, `src/push/liveActivity.ts`

## Group 5: proof
- [ ] T012 Manual: CarPlay Simulator and Lock Screen screenshots of the five states, VoiceOver read-out, largest Dynamic Type; requirement amendment for point 1 in `docs/requirements/surfaces-and-pro-gating.md`.

## Review lows
(filled by implement)

## Points to decide

1. Critic: a region change mid-alarm (the app's update or the server's `la-move`) would keep the old
   region's start under the new name. Proposed: a region change replaces the start with the new
   region's start when the server has one, else clears it; both tests get this case.
2. Critic: the server's `startedAt` would live only in memory and vanish on a restart, so running
   activities lose their timer. Proposed: store it in the saved `StatusRecord`
   (`src/push/changes.ts`), so it survives a restart.
3. Critic: a stale alarm would keep counting on the Lock Screen, `.small` and StandBy. Proposed: a
   stale alarm hides the timer everywhere and in the spoken sentence (REQ-SURF-003: it may be over).
4. Critic: a String accessibility label would say "12 minutes" while the screen shows 20. Proposed:
   the activity is one accessibility element that combines its children, so VoiceOver reads the
   live timer text; the test checks the structure (one element, its parts), not a fixed string.
5. Critic: `.relative` shows seconds. Checked in Apple's docs: `Text(.currentDate, format:
   .reference(to: start, allowedFields: [.hour, .minute]))` (iOS 18+) updates itself, minutes and
   hours only. Proposed wording: "Started 12 min ago" / «Началась 12 мин назад» /
   «Почалася 12 хв тому»; the minimal view shows the bare "12 min". Owner decides the wording.
6. Collision: the matrix row (`surfaces-and-pro-gating.md:19`) gains "alert duration" (T000).
7. Collision: ALERT-push AC-10 (shape per state) and AC-4's timer in the minimal view. Proposed: the
   minimal view keeps the state glyph and adds the minutes beside it only in a fresh alarm.

Decisions (owner, 2026-11-12, plan approved the same day; «Принимаю все»):

1. - Decision: accepted
2. - Decision: accepted
3. - Decision: accepted
4. - Decision: accepted
5. - Decision: accepted (wording as proposed)
6. - Decision: accepted
7. - Decision: accepted
