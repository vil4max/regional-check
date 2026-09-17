# Agent Task — RD-8: CarPlay tab bar with Status and Details tabs

Assignee: drivecheck-ios
State: open
Requested by: owner — waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Parent: `docs/tasks/redesign.md`
Requirements: REQ-SURF-001 (full status form in CarPlay titles), REQ-SURF-005 (nearby alerts in every status), REQ-SURF-006 (CarPlay tabs free), REQ-REFRESH-004, REQ-REFRESH-007, REQ-REGION-009 (location denied, short CarPlay text)
Changes a requirement: no (implements approved requirements)
Owned files: `RegionalCheck/App/CarPlaySceneDelegate.swift`, `RegionalCheck/App/CarPlayTemplateBuilder.swift`, a new CarPlay Details builder file under `RegionalCheck/App/`, `RegionalCheckTests/CarPlayTemplateBuilderTests.swift`, `RegionalCheckTests/CarPlayConnectionTests.swift` if tab wiring needs it, new catalog keys for this task only
Out of scope: the Map tab (RD-9), refresh timing and retry logic (`CarPlayRefreshCoordinator`, `CarPlayLoadState` behavior), iPhone views, widgets, `Theme.swift`
Failure conditions: the root is not a tab bar with Status and Details; the Details tab or any status text is Pro-gated; a stale cached status shows a status marker; the pushed Details screen still exists; data rows refresh more often than every 10 s; refresh behavior changes; strings are hard-coded
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Make the CarPlay root a `CPTabBarTemplate` with **Status** (`steeringwheel`)
and **Details** (`list.bullet`) tabs. The Map tab is added later by RD-9 (only
after the RD-3 spike confirms Variant B).

## Sources

- `docs/tasks/redesign.md` §7.1 and §7.2; owner rulings R3 (full form
  "Air Raid Alert" in titles), R5 ("Nothing nearby" row), R8 (keep 🚨/🟢 marker).
- Casing rule: `docs/design/redesign/geometry-and-tokens.md` §6.
- Mockups: `carplay-status-clear.png`, `carplay-status-alert.png`,
  `carplay-status-stale.png`, `carplay-details.png`.

## Behavior

Status tab (`CPInformationTemplate`, leading layout):

| # | Title | Detail |
|---|---|---|
| 1 | Region name | "Automatic · Updated HH:mm" / "Region selected manually · …" / "Outside Ukraine · previous region" |
| 2 | "No air raid alert in your region" / "Alert active in your region" | "Alerts in N of 25 regions of Ukraine" (count from the snapshot, never hard-coded) |
| 3 | "Nearby: Sumy, Poltava" or "Nothing nearby" | "N neighboring regions under alert" / "Neighboring regions are clear" |

- Title: status marker + full status title; no current data → "No Current
  Data" without a marker, rows: region + last update, "Last known status:
  {status}" + "Data may be outdated — refresh", Pro source row.
- Location denied row stays (short text). Action: Refresh only ("Checking…"
  while loading). The Details button is removed.

Details tab (`CPListTemplate`, text + detail, no images, max 12 items):
YOUR REGION, UKRAINE, DATA sections as in §7.2; reuse the status details
pipeline (`StatusDetailsViewModel`, existing detail rows); source only for Pro.

Template depth stays within the driving task limit; no push beyond one level.

## Tests

- `CarPlayTemplateBuilderTests`: tab structure, Status rows per state (clear,
  alert, stale, location denied, outside Ukraine), nearby row in quiet and alarm
  (REQ-SURF-005), no marker for stale (REQ-REFRESH-007), Details rows free
  (REQ-SURF-006), Pro-only source row. Name tests with the REQ IDs.

## Acceptance

- CarPlay screenshots of Status (clear, alert, stale) and Details from the iOS
  Simulator CarPlay window, if it renders on this machine; otherwise builder
  test output plus a note (the owner switched CarPlay checks to the simulator,
  not a personal iPhone).
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
