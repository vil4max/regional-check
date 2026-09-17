# Agent Task — RD-6: Alert map row and full-screen map on iPhone

Assignee: ios-home (after RD-5 lands)
State: open
Requested by: owner — conditional waves 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "waves 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: REQ-SURF-002 (map free), REQ-REFRESH-001 (on-demand loads only), `docs/core.md` Vision (Alert map row, amended 2026-09-17)
Changes a requirement: no
Owned files: `RegionalCheck/Views/MapCardView.swift` (replaced by the row), a new full-screen map view under `RegionalCheck/Views/`, the grouped-list row in the Status screen (coordinate the one-line insertion point with RD-5's landed layout), `RegionalCheck/Views/MapViewModel.swift` only if presentation needs a hook, `RegionalCheckTests/MapViewModelTests.swift`, `AppScenarioTests.swift` map scenario, related snapshots, new catalog keys for this task only
Out of scope: fetch policy of `MapImageSource`/`MapViewModel` (MAP-1/MAP-2 rules unchanged), CarPlay Map (RD-9), `Theme.swift`
Failure conditions: the map polls or prefetches; image fetch time is replaced by `checkedAt`; the map is Pro-gated; the full-screen cover lacks Close, swipe down or "Refresh map"; the old top map card remains
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Replace the map card at the top of Home with an "Alert map" row in the grouped
list (map icon, label, image age, chevron) that opens the map in a full-screen
cover with Close, swipe down and "Refresh map" (rulings R2, Q11).

## Sources

`docs/tasks/redesign.md` §6.4; `states.md` rows 6a–6c
(`map-fullscreen-loaded/loading/failed.png`); `docs/tasks/map-on-home.md`
(MAP-2 rules to keep).

## Behavior

- Load on cover appear (when empty) and on "Refresh map" only; night variant in
  dark; VoiceOver label from the snapshot; image age from fetch time.
- Loading: spinner "Loading map…" (proposal); failed: `map.error` plus
  "Check your connection and refresh." (proposal).

## Tests

Existing `MapViewModelTests` stay green; scenario test for row → cover →
refresh; snapshots for row and cover states.

## Acceptance

Simulator screenshots next to state PNGs; `just verify` passes.

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
