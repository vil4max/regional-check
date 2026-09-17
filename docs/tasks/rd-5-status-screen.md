# Agent Task — RD-5: Status screen layout and states

Assignee: ios-home (starts after RD-4 lands)
State: open
Requested by: owner — waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Parent: `docs/tasks/redesign.md`
Requirements: REQ-SURF-001 (full title form, casing), REQ-SURF-002, REQ-SURF-005 (nearby alerts in every status), REQ-REFRESH-006 (stale), REQ-REGION-007 (notice), REQ-REGION-009 (location denied)
Changes a requirement: no (implements approved requirements; REQ-SURF-005 changes `StatusDetailsProvider` behavior, which is approved)
Owned files: `RegionalCheck/Views/StatusView.swift`, `StatusToolbar.swift`, `StatusDetailsView.swift`, `HomeView.swift`, `HomeViewModel.swift`, `RegionalCheck/AI/StatusDetailsProvider.swift` (nearby rule only), new Status subviews under `RegionalCheck/Views/`, `RegionalCheckTests/HomeViewModelTests.swift`, `StatusDetailsViewModelTests.swift`, `StatusDetailsTestSupport.swift`, Status/Home snapshot baselines, new catalog keys for this task only
Out of scope: bottom bar and round button (RD-4, landed), the map card to row change and full-screen map (RD-6 — keep the current map card where it is), onboarding/About/Paywall (RD-16), `Theme.swift` (RD-2), CarPlay, widgets, cold start (RD-15B)
Failure conditions: the safety signal depends on Pro; a stale or checking state shows a clear/alert color; "25" is hard-coded; nearby alerts are hidden during an alarm; existing behaviors (location denied + Open Settings, region notice with Undo, last known status, Pro source label, secondary region) disappear; text truncates before the hero shrinks at AX5; tokens are hard-coded
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Rebuild the Status (Home) tab to the redesign: navigation row, hero (tick ring,
disc, plain symbol), title, region row, meta line, Summary card (details text,
nearby warning, country line, segment bar, affected list), grouped list (Also
watching), in all four states.

## Sources

- `docs/tasks/redesign.md` §6.1 (layout and state table), rulings R3, R4, Q9, Q10.
- Binding: `docs/design/redesign/geometry-and-tokens.md` (hero ring 156 pt,
  r 74, 60 ticks 5 × 1.6 pt round caps, flat `ringStatus`; disc 108; symbol 54;
  Pro palette; casing rule) and `docs/design/redesign/states.md` rows 1–4, 7, 8.
- Mockups: `iphone-home-clear.png`, `iphone-home-alert.png`,
  `iphone-home-stale.png`, `iphone-home-pro-clear.png`,
  `iphone-home-pro-stale.png`; states `status-checking.png`,
  `status-pro-off.png`, `status-location-denied.png`,
  `status-region-change-notice.png`, `status-reduce-transparency.png`,
  `status-ax5.png`.

## Behavior

- State table from §6.1 (accent, symbol, title, meta, summary, warning line,
  country line, segments). Titles use the full form: "No Alert",
  "Air Raid Alert", "No Current Data", "Checking…".
- Nearby-alerts warning shows in quiet **and** alarm (REQ-SURF-005): change the
  quiet-only guard in `StatusDetailsProvider.nearbyWarning`; copy reuses
  `status.details.nearby_alerts*` keys unless the mockup wording is required.
- Regions-under-alert count and segment bar come from the snapshot.
- Location denied row, region change notice, last known status, Pro source
  label, secondary region ("Also watching") keep working; copy per
  `states.md` (existing keys win).
- AX5: hero shrinks to 108 / 76 pt before text truncates; content scrolls.
- Reduce Motion: no pulse or rotation. Pro palette: chrome only.

## Tests

- `StatusDetailsViewModelTests` / provider tests: nearby warning present in
  alarm and quiet (REQ-SURF-005), absent when no neighbors alert.
- `HomeViewModelTests`: title and accent per state (REQ-SURF-001), stale
  detection (REQ-REFRESH-006), count from snapshot.
- Snapshots for the four states, Pro on/off, AX5 re-recorded on purpose.
  Name tests with REQ IDs.

## Acceptance

- Simulator screenshots next to each mockup and state PNG.
- `just verify` passes.

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
