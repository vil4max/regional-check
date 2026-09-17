# Agent Task — RD-9: CarPlay Map tab, map image plus text (Variant B)

Assignee: drivecheck-ios (after RD-8 lands and the RD-3 result lands)
State: open
Requested by: owner — conditional batches 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after batches 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve batches 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; batches 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "batches 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: REQ-SURF-002, REQ-SURF-006 (Map tab free), REQ-REFRESH-001 (on-demand image loads), REQ-PROVIDER-002 (polite load)
Changes a requirement: no
Owned files: a new CarPlay map builder under `RegionalCheck/App/`, tab wiring in `CarPlaySceneDelegate.swift` (RD-8 landed), tests for the map rows and image-age label, new catalog keys for this task only
Out of scope: Variant A (MapKit pins), `MapImageSource` fetch rules, iPhone map (RD-6), refresh timer
Failure conditions: the image loads on a timer; text is drawn into the image; the tab is Pro-gated; a stale state shows a status color; the app pushes templates beyond the driving task depth; the iOS 27 landscape image is used without evidence
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Add the CarPlay **Map** tab: header "Ukraine alert map" + image age, an image
row with the upstream night map using `CPListImageRowItemCardElement` (iOS 26
API, available on iOS 27; decision recorded in `docs/tasks/redesign.md` §12),
text rows "N of 25 regions under alert" (count from snapshot) and the affected
list, and a "Refresh map" row (ruling Q14).

## Sources

RD-3 result (`docs/tasks/carplay-map-spike.md`, result section); ADR 0011;
`docs/tasks/redesign.md` §7.3; mockups `carplay-map-b-*.png`; light/dark via
`CPTemplateApplicationScene.contentStyle`.

## Behavior

- Load on tab appear and on Refresh map only; handle failure and HTTP 429 per
  the spike; clear state "No regions under alert"; no current data shows last
  known with age, no status color.
- Accessibility label from the snapshot.
- Draft App Review note text in the report (Q15).

## Tests

Builder tests for rows per state; image age label; no timer-driven loads.

## Acceptance

Builder test output and, if a CarPlay window is available on the simulator,
screenshots (never the owner's iPhone); `just verify` passes.

## Completion

Own worktree and branch from current `origin/main`, atomic commits, `just verify`
(copy `Tooling/backend/build/` from the primary checkout if the Prefire plugin
prompt blocks it), then `READY` to drivecheck-integrator (branch, head SHA,
worktree path, this brief, verify result, `release-prep: no`). Agent Result to
drivecheck-product with screenshots or simulator captures of every changed
state next to the mockup PNG. Never merge, push, or tag.

## Required final report

```markdown
# Agent Result
## Outcome
COMPLETED | BLOCKED_CORRECTLY | FAILED
## Summary
## Research findings
## Files changed
## Tests (REQ IDs)
## Screens vs mockups
## Commands executed
## Verification results
## Assumptions made
## Risks
## Open questions
```
