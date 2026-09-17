# Agent Task — RD-10: Widgets and Live Activity restyle

Assignee: drivecheck-ios-design (after RD-2 lands; not in parallel with another task on `RegionalCheckWidgets/`)
State: open
Requested by: owner — conditional batches 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after batches 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve batches 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; batches 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "batches 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: REQ-SURF-001 (short form), REQ-SURF-002, REQ-SURF-003 (honest age), REQ-REFRESH-008, REQ-REFRESH-009, REQ-SURF-004 (Pro loss)
Changes a requirement: no
Owned files: `RegionalCheckWidgets/*` (views, Live Activity, color mirror), widget catalog keys for this task only, widget snapshot/previews, `RegionalCheckTests/WidgetTimelineBuilderTests.swift` only if presentation data changes
Out of scope: widget reload schedule and fetch logic (REQ-REFRESH-008 unchanged), app views, CarPlay app templates
Failure conditions: a stale widget shows "Updating…" or a clear color; a known alarm is hidden; Pro-only content leaks to free; widget colors differ from the app tokens; timeline schedule changes
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Restyle the Lock Screen Live Activity, Dynamic Island compact, small and medium
widgets to the redesign, including stale and checking variants, and report how
they appear on the CarPlay Dashboard.

## Sources

`docs/tasks/redesign.md` §8; `geometry-and-tokens.md`; mockups
`widgets-live-activity.png`, `states/widgets-live-activity-stale.png`,
`states/widgets-live-activity-checking.png`; `states.md` row 9 (the
`liveActivity.stale` key currently says "Updating…": use it only for checking
and add a stale wording).

## Behavior

- Short status forms ("No Alert", "Alert"), status disc, region, time.
- Stale: clock symbol, `statusStale`, "No Current Data" / "last known".
- Medium (Pro): Current and Also watching tiles, refresh button (App Intent).
- Widget target mirrors app tokens (it cannot import `Theme.swift`); keep
  values identical to `geometry-and-tokens.md`.

## Tests

Widget previews/snapshots for fresh, aging, expired, checking; wording tests
where a key changes (REQ-SURF-001).

## Acceptance

Screenshots of each widget family and the Live Activity; a short report of the
CarPlay Dashboard appearance (simulator only); `just verify` passes.

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
