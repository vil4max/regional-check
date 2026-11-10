Base: d1b867243982adc8d37c49ff2a6bbd2c7abfaca4

# DETAILS-compact: plan

Spec: `specs/DETAILS-compact/spec.md`. Branch `claude/details-compact` (from `main` d1b8672).

## Business rules (read first)

| Rule | Source |
|---|---|
| Details groups Live Activity and notifications into one "Alerts" section; captions short; purchases, data source and version at the bottom in one block; no country card | owner, 2026-11-10 (spec Request) |
| A switch never reads "on" while iOS refuses it; a note offers Open Settings | REQ-SURF-008, REQ-PUSH-005 |
| The notification switch says what leaves the device | REQ-PUSH-006 |
| The location-denied row shows when access is blocked | REQ-REGION-009 |
| Nearby alerts stay on Status as their own row | REQ-SURF-005 |

## Acceptance criteria and blast radius

AC-1..AC-6 of the spec. Blast radius: `RegionalCheck/Views/DetailsView.swift`,
`AllClearPushSwitch.swift`, a new `DetailsLayout.swift` (pure section order), `Localizable.xcstrings`,
`DetailsView` previews (Prefire snapshot baselines), docs (ADR 0015 note, `core.md:35`). Must not
touch: Status tab, CarPlay, widgets, the push controller, `StatusDetails*` code (left in place,
see Approach). Risk class: normal.

## Baseline

Commit `d1b867243982adc8d37c49ff2a6bbd2c7abfaca4`. `ios-verify --base HEAD`: PASS, 520 tests, 0
failed (`build/verify/baseline.log`).

## Code facts

- Details today: `StatusSummaryCard` (AI summary rows, the "N of 25" country line, segment bar and
  region list), location section (only when blocked), Live Activity section, all-clear section,
  purchases section, data section, version text (`DetailsView.swift:43-61`).
- The summary card exists only on Details (`StatusSummaryCard(` appears only in
  `DetailsView.swift`); `MainTabView.swift:113` and `DetailsView` drive `statusDetailsLifecycle`.

## Approach

Options, neutral order:

- **A. Remove the summary card from Details; leave the summary pipeline in the code.** The card,
  the `statusDetailsLifecycle` on Details and the Details-side `statusDetailsViewModel` parameter
  go; `StatusDetails*`, `StatusSummaryCard` and the AI summarizer stay compiled but unshown, with a
  backlog item to remove or reuse them. Cost: small diff. Counterargument: dead code stays, and
  `MainTabView` keeps computing a summary nobody sees.
- **B. Remove the card and the whole summary pipeline** (`StatusSummaryCard`, `StatusDetailsView`,
  `StatusDetailsViewModel`, providers, the AI summarizer, their tests, the lifecycle in
  `MainTabView`). Cost: large diff across views, AI and tests, ADR 0015 and ADR 0009 touched.
  Counterargument: big blast radius for a screen tidy-up.
- **C. Keep the AI summary text, drop only the segment bar and region list.** Cost: smallest.
  Counterargument: the visible "N of 25 regions" sentence is the country card the owner asked to drop.

Agent's lean: **A** now, B as a separate cleanup task.

Layout after the change (top to bottom): location-denied section (only when blocked) → **Alerts**
(Live Activity switch + its one-line caption + system-off note; notification switch + one-line
caption + system-off note) → **About** (Restore Purchases row, data source link, disclaimer line,
version line). The section order is a pure function `DetailsLayout.sections(isLocationBlocked:
hasPushSwitch:)` returning `[DetailsSection]`, which `DetailsView` iterates, so the order is tested.

## Files and types

- New `RegionalCheck/Views/DetailsLayout.swift`: `enum DetailsSection { case location, alerts, about }`
  and `sections(isLocationBlocked:hasPushSwitch:)`.
- `DetailsView.swift`: drop `StatusSummaryCard` and the lifecycle; one `alertsSection` holding both
  switches; `aboutSection` merging purchases, data and version.
- `AllClearPushSwitch.swift`: becomes a row inside Alerts (no own section header).
- `Localizable.xcstrings`: new `details.section.alerts` ("ALERTS" / "ТРИВОГИ" / "ТРЕВОГИ"),
  `details.section.about` ("ABOUT" / "ПРО ЗАСТОСУНОК" / "О ПРИЛОЖЕНИИ"); shorter
  `details.allClear.caption`: "Sends this device's token and last region to Drive Check." /
  "Надсилає токен пристрою й останній регіон на сервер Drive Check." / "Отправляет токен
  устройства и последний регион на сервер Drive Check."; `about.section.allClear` retired.
- Docs: ADR 0015 note (summary leaves Details), `core.md:35` ("the summary" removed from the phone list).

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1, AC-2, AC-5 | `DetailsLayoutTests` "the sections are location, alerts, about" | blocked → `[.location, .alerts, .about]`; not blocked → `[.alerts, .about]`; no `.summary` case exists |
| AC-2 | same file: "without a push controller, Alerts still shows" | `hasPushSwitch: false` → `.alerts` present |
| AC-3 | existing `DetailsViewModelTests` (Live Activity off) and `PushRegistrationTests` (`deniedPermissionLeavesSwitchOff`, `revokedPermissionDeletesToken`) unchanged | still pass |
| AC-4, AC-6 | `DetailsStringsTests` "Details strings in en, uk, ru, captions one sentence" | each key has 3 values; caption has one sentence (no ". " inside) and ≤ 70 characters |
| AC-1..5 visual | Details snapshot baselines re-recorded (`-testPlan Snapshots`) | not in the gate; evidence in `build/review/runtime/` |

## Risks

- Collision audit (read-only):

| Source | Behaviour implied | Scope | Decision that stands |
|---|---|---|---|
| `docs/decisions/0015-two-tab-phone-ia.md:33` | Details holds the full summary (provider rows, country count) | phone IA | none later; owner 2026-11-10 asks to drop the country card |
| `docs/core.md:35` | the phone adds "the map, the summary, settings" | product | same owner answer; core needs a dated amendment |
| `RegionalCheckTests/StatusSummaryCardTests.swift` (REQ-SURF-005) | the summary card's visibility rules | card | tests stay valid for the kept type (option A) |
| `docs/requirements/surfaces-and-pro-gating.md` REQ-SURF-005 note "the summary moved to the Details tab" | summary on Details | requirement note | amend with a dated note |

- Snapshot baselines for the five Details previews change; the Snapshots plan only warns.
- Localization: Ukrainian/Russian section names upper-case like the existing headers.
- Test host: layout tests are pure; no live services.

## Tasks

## Group 1: Layout
- [ ] T001 Test: `DetailsLayoutTests` (section order, no summary) proves AC-1, AC-2, AC-5. Files: `RegionalCheckTests/DetailsLayoutTests.swift`
- [ ] T002 Implement: `DetailsLayout`, `DetailsView` Alerts and About sections, card removed. Files: `RegionalCheck/Views/DetailsLayout.swift`, `DetailsView.swift`, `AllClearPushSwitch.swift`
- [ ] T003 Test + Implement: strings and short captions prove AC-4, AC-6. Files: `RegionalCheckTests/DetailsStringsTests.swift`, `Localizable.xcstrings`
## Group 2: Docs and evidence
- [ ] T004 Docs: ADR 0015 note, `core.md:35`, REQ-SURF-005 note; backlog item for option B. Files: `docs/`
- [ ] T005 Evidence: re-record Details snapshots and save them to `build/review/runtime/`.

## Review lows
(filled by implement)

## Verification

`ios-verify` (background), `scripts/spec-trace.sh`, the Snapshots plan for the Details previews, and
a look at `ios-verify run-sim` on the Details tab.

## Points to decide

`plan-critic` findings, unchanged, each with my proposed answer:

1. [plan:55-56] The About block lists only Restore, data link, disclaimer and version, but today's
   purchases section also has the Drive Check Pro row (the only route from Details to the Pro sheet)
   and Manage Subscription (`DetailsView.swift:235-278`); REQ-SURF-007 (`surfaces-and-pro-gating.md:162`)
   and the matrix row (`surfaces-and-pro-gating.md:11`) require both. Proposed answer: both rows stay
   in About, under the same conditions as today; the matrix row is amended for the removed full
   summary; a `DetailsLayout` test asserts the About rows (Pro row when offered or owned, Manage only
   with an active subscription, Restore always). Fixed in the plan.
   - Decision: accepted
2. [plan:71] Retiring `about.section.allClear` breaks the REQ-PUSH-007 test
   (`PushRegistrationTests.swift:135`); `about.section.liveActivity`, `.purchases`, `.data` become
   unused yet are asserted in `PurchaseSettingsViewModelTests.swift:59-60`. Proposed answer: the
   tests switch to `details.section.alerts` and `details.section.about`, and the four old header keys
   are removed from the catalog. Fixed in the plan (T003).
   - Decision: accepted
3. [plan:40-44] Removing the card drops the only place the phone shows the data source name
   (`StatusSummaryCard.swift:101-108`, `DetailsViewModel.swift:59-62`, tested at
   `DetailsViewModelTests.swift:60`). Proposed answer: the source name moves into About, on the data
   source link row ("Data source (Ubilling)", as today's link text already reads); `sourceLabel` and
   its test stay. Fixed in the plan.
   - Decision: accepted
4. [plan:64] The Live Activity permission `.task` and `.onChange(of: scenePhase)` sit on
   `liveActivitySection` (`DetailsView.swift:115-118`). Proposed answer: they move to
   `alertsSection`, so the switch still updates after Open Settings and back (REQ-SURF-008). Fixed in
   the plan.
   - Decision: accepted
5. [plan:81] The "≤ 70 characters" limit has no source, and the test checks one caption while AC-2
   covers both. Proposed answer: drop the character limit; the test checks that both captions (Live
   Activity and notification) are one sentence in each language. Fixed in the plan.
   - Decision: accepted

Owner's answers at this gate (2026-11-10): approach A; points 1-5 accepted as fixed in the plan.
