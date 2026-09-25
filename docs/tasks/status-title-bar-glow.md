# Task — Transparent Status title bar: the ring glow is not cut (3.1.0 build 4)

Assignee: Drive Check
State: claimed
Requested by: owner (direct, 2026-09-25)
Evidence: —
Depends-on: none
Parallelism: none
Profile: fix
user-visible: The status colour glows all the way to the top of the screen; no dark band behind the title.

## Current status and authorization

Current outcome: plan approved; no step started.
Authorized scope: the owner, 2026-09-25, with a build 3 screenshot (TestFlight, iPhone 15 Pro Max, Air Raid Alert, Kyiv): "Нужен прозрачный навбар потому что сейчас размытие цвета от статуса перекрывается навбаром" (the bar must be transparent, because the bar now covers the blur of the status colour). The plan "Transparent Status title bar: the ring glow is not cut (3.1.0 build 4)" was approved in plan mode the same day ("User has approved your plan"). It carries three decisions: ship as 3.1.0 build 4, add REQ-SURF-012 as approved, and accept that scrolled Status content passes under the title without blur.
Blocking decisions: none
Permitted deviations: none
Material assumptions: the simulator renders the scroll edge effect at run time, so a scenario screenshot shows the band. Check: the before screenshot. If it does not, the device check on build 4 is the only visual evidence.
Next step: Writer step 1.
Requirements: REQ-SURF-012 (`docs/requirements/surfaces-and-pro-gating.md`, added by step 1)
Acceptance specs: a REQ-SURF-012 test that fails before the fix
Owned files: `docs/requirements/surfaces-and-pro-gating.md`, `RegionalCheck/Views/StatusView.swift`, a new or existing Status test file, Status/Home snapshot PNGs only if their title area changes, `RegionalCheck.xcodeproj/project.xcproj` (build number), `CHANGELOG.md`, `docs/operations/releases/3.1.md`
Out of scope: Details (it keeps the edge effect); `StatusToolbar` itself; any other layout change
Failure conditions: a dark band or blur still sits behind the title on Status; Details loses its edge effect; a snapshot changes outside the title area

## Reproduction

On build 3, open Status during an alert. The red glow around the ring stops at a horizontal line behind "Drive Check": above it a darker blurred band covers the top of the glow. Cause: `StatusView` attaches `StatusToolbar` with `.safeAreaBar(edge: .top)` (`RegionalCheck/Views/StatusView.swift:97`). The scroll view below a safe-area bar draws an automatic scroll edge effect that blurs and dims what is under the bar. The toolbar has painted no backing since 429ae28. Apple: `scrollEdgeEffectHidden(_:for:)` "Hides any scroll edge effects for scroll views within this hierarchy", iOS 26.0+.

## Writer steps

- [ ] Failing spec: REQ-SURF-012 and a test that `StatusView` hides the top scroll edge effect; before screenshot of `just scenario alertActive`: the test fails
- [ ] Fix: `.scrollEdgeEffectHidden(true, for: .top)` on the Status scroll view; comment updated; after screenshot: `just verify`
- [ ] Build 4: `CURRENT_PROJECT_VERSION` 4, `3.1.md`, `CHANGELOG.md`: `just verify`, `just release --check`

## Evidence history

- 2026-09-25: brief opened on `b040162`.

## Untested scope

- The edge effect on a real device: build 4 device check.
