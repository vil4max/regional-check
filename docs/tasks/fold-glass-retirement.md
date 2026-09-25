# Task — Retire the fold glass from 3.1.0 (build 3)

Assignee: Drive Check
State: done
Requested by: owner (direct, 2026-09-24), relayed first by the SDLC Orchestrator and confirmed in the Drive Check session
Evidence: coverage matrix below (`spec_trace.py matrix`: 0 requirements, 0 GAP; no card cites a kept requirement, and the retired ids are named in Scope only, see Deferred); `/code-review` per card (Round 1 reviews below) and a whole-round `/code-review high`; `just verify` OK on Cards 2 and 3; `lock --check` clean after `lock --write` (39 approved)
Depends-on: none
Parallelism: none
Profile: round
Plan hash: 303d41c1f530ba188491e90bed36817111bfb1d945dd90fc30ce6985654cfb70

## Current status and authorization

Current outcome: all three cards landed (50095d7, 6ffe3c2, 65eafa2) plus review repair f9fb45a; Card 4 (core lab clause, KIT-D-046) added and landed 2026-09-25 as 99c2e73 with the owner's approval; push, `tf-3.1.0-3` and the ASC edits are pending.
Authorized scope: the owner, 2026-09-24. In the SDLC Orchestrator session: "наклон статуса
непонятная фича, зачем она? у меня 15 про макс, не дуо", then "убрать". In the Drive Check session,
AskUserQuestion "Fold glass … Что с ним делаем в 3.1.0?", answer verbatim: "Убрать из 3.1.0
(Recommended)". The round plan (three cards below) was approved in the Drive Check session through
plan mode the same day ("User has approved your plan"). Card 4 and the push were approved on
2026-09-25, AskUserQuestion "Оркестратор передал ваше решение KIT-D-046 … Что из этого делаем?",
answer verbatim: "Правка core + push (Recommended)".
Blocking decisions: none
Permitted deviations: none
Material assumptions: the build 2 device checklist (Live Activity and widget) moves unchanged to
build 3; check: the owner runs it on build 3.
Next step: `just verify` on the round head, push (approved), `just tf-check` and `tf-3.1.0-3`.
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
wiring and the Details switch; update the 3.1.0 release documents; ship it as 3.1.0 build 3. Amend core's lab clause to point at
kit decision KIT-D-046 (lab experiments ship only to TestFlight).

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
- `docs/core.md`'s lab clause says experiments run only in development and TestFlight builds, gated
  at run time by StoreKit's `AppTransaction` environment, and cites KIT-D-046.
- `just verify` passes; `just tf-check` prints Ready.

## Constraints

- No new feature and no behavior change outside the effect and its switch.
- The core lab clause stays; it names no feature.
- Past briefs and historical 3.0 documents stay as history.
- Push, the `tf-3.1.0-3` tag (after `just tf-check` Ready), ASC edits, "Add for Review" and
  `v3.1.0` follow the owner rules.

## Cards

#### Card: fg-retire-reqs — retire the fold glass requirements

model: sonnet
product question: n/a — documentation of a removal the owner already decided
metric: n/a — no user-facing change in this card
threshold: n/a — no user-facing change in this card
user-visible: none

##### Card 1 dispatch — requirement retirement (2026-09-24)

Objective: mark the four fold glass requirements named in Scope retired and remove the effect from current docs.
Sources: the retired requirements named in Scope; owner answer "Убрать из 3.1.0 (Recommended)", 2026-09-24
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
Sources: the switch and effect requirements named in Scope, all retired by Card 1
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

#### Card: core-lab-testflight-only — the lab clause points at KIT-D-046

model: sonnet
product question: n/a — a charter sentence the owner approved; no user-facing change
metric: n/a — no user-facing change
threshold: n/a — no user-facing change
user-visible: none

##### Card 4 dispatch — core lab clause (2026-09-25)

Objective: append the owner-approved sentence to the lab clause in `docs/core.md`.
Sources: KIT-D-046 (kit `docs/decisions/KIT-D-046-lab-experiments-ship-only-to-testflight.md`); owner answer "Правка core + push (Recommended)", 2026-09-25
Intended deviations: written by the integrator instead of a `slice-writer`, because it is one approved sentence
Boundaries: `docs/core.md` lab paragraph only; stop if any other core sentence would change
Output: one commit; `git diff --check` and `just trace`

## Deferred

| Requirement | Status | Reason | Backlog | Expiry |
|---|---|---|---|---|

No deferral. Deviation from the round doc, on the SDLC Orchestrator's direction of 2026-09-25: the
retired ids are named only in Scope and the status block, not inside card blocks, so the matrix does
not list them; a retirement is not a deferral. Kit defect: `spec_trace.py` matrix has no retired
case (`spec_trace.py:763-766`), post-pilot fix batch. The four N/A rows the owner approved earlier
(2026-09-25, AskUserQuestion "Закрытие round fold glass: … Одобряете эти четыре строки одним
пакетом?", answer "Одобряю N/A для REQ-FG (Recommended)") were removed with this change. Evidence of the retirement:
the Status lines in `docs/requirements/fold-glass.md`, the default `spec_trace.py` report no longer
listing REQ-FG ids (`spec_trace.py:870-871`), and no test citing them.

## Writer steps

- [x] Card 1, retire REQ-FG in docs: `just trace`, `brief_lint --strict` — 50095d7
- [x] Card 2, remove the code and switch: `just verify` — 6ffe3c2
- [x] Card 3, release docs and build 3: `just verify`, `just release --check` — 65eafa2
- [x] Card 4, core lab clause: `git diff --check`, `just trace` — 99c2e73

## Evidence history

- 2026-09-24: brief opened on `97c0fa8`.
- 2026-09-24: Card 1 by a `slice-writer` (sonnet) in its own worktree, landed ff-only as `50095d7`; `just trace` 39 of 39 covered, 0 brief problems; `brief_lint --strict` 0 problems. `just verify` not run for this docs-only landing; it runs after Card 2.
- 2026-09-24: Card 2 by a `slice-writer` (opus) in its own worktree, landed ff-only as `6ffe3c2`; `just verify` printed `verify OK (DoD)` (trace 39 of 39, lint 0, build and all tests green); four Details baselines re-recorded, `Details-AX5` byte-identical, no Home baseline changed; `git grep` for `FoldGlass|foldGlass|FoldTilt|foldEffect` outside `docs/` is empty.
- 2026-09-25: Card 3 by a `slice-writer` (sonnet), landed ff-only as `65eafa2`; `just verify` OK, `just release --check` OK on its HEAD; review repair `f9fb45a`. Close: `spec_trace.py matrix` 0 GAP, `lock --write` (39 approved), `lock --check` clean.
- 2026-09-25: Card 4 (core lab clause) written by the integrator as 99c2e73; `git diff --check` clean, `just trace` 39 of 39. The brief was reshaped on the SDLC Orchestrator's direction: retired ids out of card blocks, the N/A Deferred rows removed; new Plan hash for the Scope and Acceptance that now include Card 4; matrix 0 requirements, 0 GAP.
- 2026-09-25: the unpushed round commits were reworded so their messages are English only (the owner's Russian answer is translated in them; the verbatim quote stays in this brief); trees unchanged, Card 1 is now `50095d7`, Card 2 `6ffe3c2`.

## Reviews

### Round 1 review — fg-retire-reqs (2026-09-24)

Review SHA: 50095d7
No findings (`/code-review medium`).

### Round 1 review — fg-remove-code (2026-09-24)

Review SHA: 6ffe3c2 (reviewed as 4685145, same tree)
No findings (`/code-review medium`).

### Round 1 review — release-3-1-0-build-3 (2026-09-25)

Review SHA: 65eafa2
[low][non-blocking] docs/operations/releases/3.1.md:55 — the first-round checklist kept its round-1 label although it was never reported, so a build 3 pass could skip the Kyiv and Control Center checks; repaired in f9fb45a.

### Round 2 review — release-3-1-0-build-3 (2026-09-25)

Review SHA: f9fb45a
No findings (`/code-review medium`, repair diff only).

### Round 1 review — core-lab-testflight-only (2026-09-25)

Review SHA: 99c2e73
No findings (`/code-review medium`).

### Whole-round review (2026-09-25)

Review SHA: f9fb45a plus this close-out (`/code-review high`, origin/main..HEAD)
[low][non-blocking] docs/requirements/.spec-lock.json:11 — lock fingerprints of REQ-FG-002/003/004 and REQ-REFRESH-010 include the wrapped tail of the Status: line (kit spec_trace.py:439-440), so a status-only edit reads as normative drift; relayed to the SDLC Orchestrator as a kit defect, accepted here.
[low][non-blocking] CHANGELOG.md:3 — Card 2 is user-visible but gets no [3.1.0] line (KIT-D-026): the effect only reached TestFlight, so App Store users have nothing to be told; accepted as a deviation.

## Coverage matrix

<!-- spec_trace:matrix:begin -->
| Requirement | Status | Detail |
|---|---|---|
<!-- spec_trace:matrix:end -->
