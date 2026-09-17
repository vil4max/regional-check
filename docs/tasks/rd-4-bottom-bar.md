# Agent Task — RD-4: iPhone bottom bar with a contextual round button

Assignee: drivecheck-ios-design (starts after RD-2 lands)
State: open
Requested by: owner — waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Parent: `docs/tasks/redesign.md`
Requirements: REQ-REGION-007 (region change notice above the bar), REQ-REFRESH-001 (manual refresh), REQ-SURF-002
Changes a requirement: no
Owned files: `RegionalCheck/Views/MainTabView.swift`, a new bottom bar view under `RegionalCheck/Views/`, `RegionalCheck/Views/StatusView.swift` only to remove the old wide Refresh button (`StatusRefreshButtonView` placement), `RegionalCheckTests/MainTabViewModelTests.swift`, snapshot baselines for Main tabs and Home, new catalog keys for this task only
Out of scope: Status screen layout (RD-5), Regions list and search behavior beyond the round Search button (RD-7), `Theme.swift` (RD-2 owns it; request token changes through drivecheck-product), CarPlay, widgets
Failure conditions: a search-role tab triggers Refresh; the round button is hidden or unreachable in any state; Refresh is allowed while already checking; VoiceOver labels are missing; content is covered by the bar without a fade and scroll; the region change notice is hidden under the bar; any token is hard-coded instead of taken from `geometry-and-tokens.md`
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Replace the wide Refresh button above the tab bar with the redesign's bottom
bar: a glass tab bar with two tabs (Status, Regions) and a separate 62 pt round
glass button to its right. The round button is Refresh on the Status tab and
Search on the Regions tab (owner rulings 4.1 #2 and #3).

## Sources

- `docs/tasks/redesign.md` §6.3 and §5; binding tokens and sizes:
  `docs/design/redesign/geometry-and-tokens.md` (tab bar 62 pt, radius 31,
  12 pt gap, round button 62 pt, `barGlass`, `glassFallback`, Pro palette
  `tabSelectedFill`/`tabSelectedLabel`/`barStroke`/`actionButtonStroke`).
- Mockups: `iphone-home-clear.png`, `iphone-home-alert.png`,
  `iphone-home-stale.png`, `iphone-regions.png`; states:
  `states/status-checking.png`, `states/status-reduce-transparency.png`,
  `states/status-region-change-notice.png`.
- RD-2 tokens and runtime palette (landed before this task starts).

## Research first

Compare with simulator screenshots on iOS 27: (a) a custom
`.glassEffect(.regular.interactive())` round button aligned to the system tab
bar; (b) `tabViewBottomAccessory`; (c) a search-role tab only on Regions plus a
custom Refresh on Status. Rejected up front: a search-role tab that refreshes
(VoiceOver would say "Search"). Pick the option that matches the mockup and
keeps system tab bar behavior; record why.

## Behavior

- Round button states on Status: normal (glass, `arrow.clockwise`), checking
  (spinner, disabled), stale (filled `statusStale`, `textOnStale` glyph).
- On Regions it is Search (`magnifyingglass`) and focuses the search field
  (RD-7 builds the search itself; this task wires the entry point).
- Labels: "Refresh" / "Checking…" / "Search regions" (reuse existing keys where
  they exist: `Refresh`, `Checking…`).
- Content scrolls under the bar with a 130 pt fade; region change notice floats
  above the bar.
- Reduce Transparency: bar and button use `glassFallback`.
- Pro palette applies to bar chrome only; status colors unchanged.

## Tests

- ViewModel tests for which action the round button shows per tab and state
  (name tests with the REQ IDs above where they prove them).
- Snapshot baselines for Main tabs and Home re-recorded on purpose; attach old
  and new PNGs to the report.

## Acceptance

- Screens match the mockups within the token rules; simulator screenshots of
  Status (clear, alert, stale, checking), Regions, Reduce Transparency, AX5.
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
