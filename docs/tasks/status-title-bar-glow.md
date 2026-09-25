# Task — Transparent Status title bar: the ring glow is not cut (3.1.0 build 4)

Assignee: Drive Check
State: done
Requested by: owner (direct, 2026-09-25)
Evidence: fail — the REQ-SURF-012 test failed on 9743968 before the fix (`Expectation failed: StatusView.hidesTopScrollEdgeEffect`); verify — `just verify` OK on b8e12ec, 8fcdc6e and f43a3e3, `just release --check` OK on f43a3e3, Snapshots plan 23 tests 0 failures; review — `/code-review medium`, one medium repaired in f43a3e3 and one low accepted (see Reviews)
Depends-on: none
Parallelism: none
Profile: fix
user-visible: The status colour glows all the way to the top of the screen; no dark band behind the title.

## Current status and authorization

Current outcome: all steps landed (9743968, b8e12ec, 8fcdc6e) with one review repair (f43a3e3); push and `tf-3.1.0-4` follow.
Authorized scope: the owner, 2026-09-25, with a build 3 screenshot (TestFlight, iPhone 15 Pro Max, Air Raid Alert, Kyiv): "Нужен прозрачный навбар потому что сейчас размытие цвета от статуса перекрывается навбаром" (the bar must be transparent, because the bar now covers the blur of the status colour). The plan "Transparent Status title bar: the ring glow is not cut (3.1.0 build 4)" was approved in plan mode the same day ("User has approved your plan"). It carries three decisions: ship as 3.1.0 build 4, add REQ-SURF-012 as approved, and accept that scrolled Status content passes under the title without blur.
Blocking decisions: none
Permitted deviations: none
Material assumptions: the simulator renders the scroll edge effect at run time, so a scenario screenshot shows the band. Check: the before screenshot. If it does not, the device check on build 4 is the only visual evidence.
Next step: push (approved with the plan), CI, `just tf-check`, `tf-3.1.0-4`.
Requirements: REQ-SURF-012 (`docs/requirements/surfaces-and-pro-gating.md`, added by step 1)
Acceptance specs: a REQ-SURF-012 test that fails before the fix
Owned files: `docs/requirements/surfaces-and-pro-gating.md`, `RegionalCheck/Views/StatusView.swift`, a new or existing Status test file, Status/Home snapshot PNGs only if their title area changes, `RegionalCheck.xcodeproj/project.xcproj` (build number), `CHANGELOG.md`, `docs/operations/releases/3.1.md`
Out of scope: Details (it keeps the edge effect); `StatusToolbar` itself; any other layout change
Failure conditions: a dark band or blur still sits behind the title on Status; Details loses its edge effect; a snapshot changes outside the title area

## Reproduction

On build 3, open Status during an alert. The red glow around the ring stops at a horizontal line behind "Drive Check": above it a darker blurred band covers the top of the glow. Cause: `StatusView` attaches `StatusToolbar` with `.safeAreaBar(edge: .top)` (`RegionalCheck/Views/StatusView.swift:97`). The scroll view below a safe-area bar draws an automatic scroll edge effect that blurs and dims what is under the bar. The toolbar has painted no backing since 429ae28. Apple: `scrollEdgeEffectHidden(_:for:)` "Hides any scroll edge effects for scroll views within this hierarchy", iOS 26.0+.

## Writer steps

- [x] Failing spec: REQ-SURF-012 and a test that `StatusView` hides the top scroll edge effect; before screenshot of `just scenario alertActive`: the test fails — 9743968
- [x] Fix: `.scrollEdgeEffectHidden(true, for: .top)` on the Status scroll view; comment updated; after screenshot: `just verify` — b8e12ec
- [x] Build 4: `CURRENT_PROJECT_VERSION` 4, `3.1.md`, `CHANGELOG.md`: `just verify`, `just release --check` — 8fcdc6e

## Evidence history

- 2026-09-25: brief opened on `b040162`.
- 2026-09-25: steps 1-3 by a `slice-writer` (opus) in its own worktree, landed ff-only. The simulator did not show the band before or after (`.artifacts/status-title-bar-glow/before.png`, `after.png` are identical in the title area), so the assumption above failed: the build 4 device check is the only visual evidence. No Status or Home baseline changed.
- 2026-09-25: review repair f43a3e3 re-recorded four Details baselines whose version line had been stale since 65eafa2 (build 3 bump); only the version line differs.

## Reviews

### Round 1 review — status-title-bar-glow (2026-09-25)

Review SHA: 8fcdc6e
[medium][blocking] RegionalCheckTests/__Snapshots__/PreviewTests.generated/Details-iPhone-16.1.png:1 — four Details baselines print the build number, stale since 65eafa2, so the Snapshots plan fails; repaired in f43a3e3.
[low][non-blocking] RegionalCheckTests/StatusTitleBarTests.swift:11 — the REQ-SURF-012 test pins the flag, not the modifier; accepted, since the simulator does not render the edge effect and the device check covers it.

### Round 2 review — status-title-bar-glow (2026-09-25)

Review SHA: f43a3e3
No findings: the repair diff is the four PNGs, whose only change is the version line "3.1.0 (2)" to "3.1.0 (4)"; Snapshots plan 23 tests, 0 failures.

## Untested scope

- The edge effect on a real device: build 4 device check.
- The REQ-SURF-012 test does not detect removal of the modifier itself (low finding, accepted).
- Snapshot baselines that print the build number break on every build bump; `just verify` and CI do not run the Snapshots plan (follow-up candidate).
