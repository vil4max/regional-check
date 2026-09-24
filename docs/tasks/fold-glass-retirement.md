# Task — Retire the fold glass from 3.1.0 (build 3)

Assignee: Drive Check
State: claimed
Requested by: owner (direct, 2026-09-24), relayed first by the SDLC Orchestrator and confirmed in the Drive Check session
Evidence: —
Depends-on: none
Parallelism: none
Profile: round
Plan hash: d3fe73b03d3139631c8e0637cea35870d8515e67ac58c4e2b196e2824d483680

## Current status and authorization

Current outcome: plan approved; no card started.
Authorized scope: the owner, 2026-09-24. In the SDLC Orchestrator session: "наклон статуса
непонятная фича, зачем она? у меня 15 про макс, не дуо", then "убрать". In the Drive Check session,
AskUserQuestion "Fold glass … Что с ним делаем в 3.1.0?", answer verbatim: "Убрать из 3.1.0
(Recommended)". The round plan (three cards below) was approved in the Drive Check session through
plan mode the same day ("User has approved your plan").
Blocking decisions: none
Permitted deviations: none
Material assumptions: the build 2 device checklist (Live Activity and widget) moves unchanged to
build 3; check: the owner runs it on build 3.
Next step: Card 1.
Requirements: REQ-FG-001, REQ-FG-002, REQ-FG-003, REQ-FG-004 (retired by this round)
Acceptance specs: none added; `FoldGlassModelTests` and `FoldGlassSettingsTests` are deleted with the code
Owned files: listed per card
Out of scope: the Metal shader lab slice; any other 3.1.0 feature; App Store Connect (owner)
Failure conditions: Home still tilts or the Details switch remains; a REQ-FG requirement still
reads approved; 3.1.0's notes or What's New still describe the effect; a Home snapshot baseline
changes

## Scope

Remove the fold glass on Home from the app and from the 3.1.0 release before submission:
retire REQ-FG-001, REQ-FG-002, REQ-FG-003 and REQ-FG-004; delete `RegionalCheck/FoldGlass/`, its
wiring and the Details switch; update the 3.1.0 release documents; ship it as 3.1.0 build 3.

## Acceptance

- Home is always drawn flat; Details has no fold glass section.
- `docs/requirements/fold-glass.md` marks all four requirements `Status: retired` with the
  owner's words and date.
- No tracked source, test, string or current document outside the retired requirement file,
  release history and past briefs mentions `FoldGlass`, `foldGlass`, `FoldTilt` or the effect.
- Home snapshot baselines are unchanged; the five Details baselines are re-recorded without the
  section.
- `CHANGELOG.md` [3.1.0] and `docs/operations/releases/3.1.md` (What's New en/uk/ru, checklists)
  no longer list the effect; `CURRENT_PROJECT_VERSION` is 3.
- `just verify` passes; `just tf-check` prints Ready.

## Constraints

- No new feature and no behavior change outside the effect and its switch.
- The core lab clause stays; it names no feature.
- Past briefs and historical 3.0 documents stay as history.
- Push, the `tf-3.1.0-3` tag (after `just tf-check` Ready), ASC edits, "Add for Review" and
  `v3.1.0` follow the owner rules.

## Cards

#### Card: fg-retire-reqs — retire REQ-FG-001, REQ-FG-002, REQ-FG-003, REQ-FG-004

model: sonnet
product question: n/a — documentation of a removal the owner already decided
metric: n/a — no user-facing change in this card
threshold: n/a — no user-facing change in this card
user-visible: none

##### Card 1 dispatch — requirement retirement (2026-09-24)

Objective: mark REQ-FG-001, REQ-FG-002, REQ-FG-003 and REQ-FG-004 retired and remove the effect from current docs.
Sources: REQ-FG-001, REQ-FG-002, REQ-FG-003, REQ-FG-004; owner answer "Убрать из 3.1.0 (Recommended)", 2026-09-24
Intended deviations: none
Boundaries: `docs/requirements/fold-glass.md`, `docs/README.md`, `docs/planning/backlog.md`, `docs/engineering/testing-strategy.md`, `docs/operations/analytics.md`; no code; stop if a requirement outside REQ-FG changes
Output: one commit; report with `just trace` and `brief_lint --strict` results and a `Conflicts found` line

#### Card: fg-remove-code — delete the effect and the Details switch

model: opus
product question: Does Home stay flat and Details lose the switch with nothing else changed?
metric: Home and Details snapshot baselines; `just verify`
threshold: Home baselines unchanged, Details baselines differ only by the removed section, `just verify` green
user-visible: The Status screen no longer tilts under glass; the switch on Details is gone.

##### Card 2 dispatch — code removal (2026-09-24)

Objective: delete `RegionalCheck/FoldGlass/`, its tests and every use, and re-record the Details baselines.
Sources: REQ-FG-001 (the switch), REQ-FG-002, REQ-FG-003, REQ-FG-004 (the effect), all retired by Card 1
Intended deviations: none
Boundaries: `RegionalCheck/FoldGlass/`, `RegionalCheck/App/AppContainer.swift`, `AppContainerFixture.swift`, `AppDelegate.swift`, `AppLaunchArguments.swift`, `RegionalCheck/Views/ColdStart/ColdStartRootView.swift`, `HomeView.swift`, `DetailsView.swift`, `DetailsViewModel.swift`, `RegionalCheck/Resources/Localizable.xcstrings`, `RegionalCheckTests/FoldGlass*Tests.swift`, `DetailsViewModelTests.swift`, the Details PNGs under `RegionalCheckTests/__Snapshots__/`; stop if a Home baseline changes
Output: one commit; report with `just verify` result and a `Conflicts found` line

#### Card: release-3-1-0-build-3 — release documents and build number

model: sonnet
product question: n/a — release bookkeeping for the removal
metric: n/a — no user-facing change beyond Card 2
threshold: n/a — no user-facing change beyond Card 2
user-visible: none

##### Card 3 dispatch — 3.1.0 build 3 (2026-09-24)

Objective: remove the effect from the 3.1.0 changelog, release note, What's New and checklists, and set build number 3.
Sources: owner answer "Убрать из 3.1.0 (Recommended)", 2026-09-24; `AGENTS.md` Versioning
Intended deviations: none
Boundaries: `CHANGELOG.md`, `docs/operations/releases/3.1.md`, `CURRENT_PROJECT_VERSION` in the app, test and widget targets; stop before any tag or push
Output: one commit; report with `just verify` and `just release --check` results and a `Conflicts found` line

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|

## Writer steps

- [ ] Card 1, retire REQ-FG in docs: `just trace`, `brief_lint --strict`
- [ ] Card 2, remove the code and switch: `just verify`
- [ ] Card 3, release docs and build 3: `just verify`, `just release --check`

## Evidence history

- 2026-09-24: brief opened on `97c0fa8`.

## Coverage matrix
