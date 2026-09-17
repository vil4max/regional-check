# Agent Task — RD-7: Regions tab restyle and search

Assignee: ios-regions (starts after RD-4 and RD-15A land)
State: open
Requested by: owner — waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Parent: `docs/tasks/redesign.md`
Requirements: REQ-REGION-001 (catalog), REQ-REGION-003 (manual pin stops following), REQ-REGION-004 (Kyiv city vs oblast), REQ-SURF-002
Changes a requirement: no
Owned files: `RegionalCheck/Views/RegionsView.swift`, `RegionalCheck/Views/RegionsViewModel.swift`, `RegionalCheck/Data/RegionsListModel.swift` if ordering/filtering lives there, a new region name matcher (in `RegionalCheck/Data/` or `Packages/DriveCheckKit` if Siri should reuse it), `RegionalCheckTests/RegionsViewModelTests.swift`, `RegionsListOrderingTests.swift`, new matcher tests, Regions snapshot baselines, new catalog keys for this task only
Out of scope: the bottom bar and round Search button wiring (RD-4, landed; this task implements the search it opens), Status screen, Siri intents (reuse is optional, no Siri behavior change), `Theme.swift`, localization of other tasks' keys
Failure conditions: searching "Kyiv"/"Київ"/"Киев" does not return both Kyiv city and Kyiv oblast; search only matches the displayed locale; an empty ALERT ACTIVE section draws an empty card; follow-location toggle or manual pin behavior changes; Pro "Pin as secondary region" disappears; tokens hard-coded
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Restyle the Regions tab to the redesign and implement region search behind the
round Search button.

## Sources

- `docs/tasks/redesign.md` §6.2, ruling Q12 (Kyiv finds city and oblast).
- Binding: `geometry-and-tokens.md`, `states.md` rows 5a, 5b, 8.
- Mockups: `iphone-regions.png`, `states/regions-search-results.png`,
  `states/regions-search-empty.png`, `states/regions-ax5.png`.

## Behavior

- Large title "Regions"; current-region card with status pill and
  "Follow location" toggle ("Switches region as you drive", proposal key),
  on-color `statusClear`.
- Sections "ALERT ACTIVE · N" (alert tint) and "OTHER REGIONS" with selected
  checkmark and per-row loading.
- Search: the field replaces the large title while active; filters both
  sections by region name in en, uk and ru regardless of the device locale,
  case- and apostrophe-insensitive (reuse `AlertRegionResolver` normalization);
  "Kyiv"/"Київ"/"Киев" returns both `.kyivCity` and `.kyivOblast`; empty ALERT
  ACTIVE is hidden, never an empty card; "No regions found" when nothing
  matches.
- Context menu "Pin as secondary region" (Pro) unchanged.

## Tests

- Matcher tests: each of the 25 regions found by its en, uk and ru name; Kyiv
  returns both; normalization cases (REQ-REGION-004).
- `RegionsViewModelTests`: filtering keeps ordering, hides empty ALERT ACTIVE,
  selecting a result pins and stops following (REQ-REGION-003).
- Snapshots: default, search results, empty, AX5. Name tests with REQ IDs.

## Acceptance

- Simulator screenshots next to the mockups.
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
