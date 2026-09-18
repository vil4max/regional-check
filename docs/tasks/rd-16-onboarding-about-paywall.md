# Agent Task — RD-16: Onboarding, About, Paywall, Outside Ukraine sheet

Assignee: ios-home (started 2026-09-17 without waiting for RD-5: the owned files do not overlap, and a shared card or strip style is requested through drivecheck-product rather than rebuilt)
State: open
Requested by: owner — conditional batches 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after batches 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve batches 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; batches 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "batches 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: REQ-REGION-008 (outside Ukraine keeps last region, sheet on leaving), REQ-SURF-002 (paywall never gates the signal), REQ-SURF-004
Changes a requirement: no (implements approved REQ-REGION-008)
Owned files: `RegionalCheck/Views/OnboardingView.swift`, `RegionalCheck/Views/Subscription/PaywallView.swift`, `PaywallViewModel.swift`, `RegionalCheck/Views/OutsideUkraineInfoSheet.swift`, presentation code for these sheets in `MainTabView.swift` (coordinate with RD-4's landed layout), `RegionalCheck/Data/RegionSelection.swift` and `RegionTracker.swift` for REQ-REGION-008, related tests and snapshots, new catalog keys for this task only
Out of scope: StoreKit product configuration, prices, App Store Connect, Status/Regions screens, `Theme.swift`
Failure conditions: the paywall implies the alert status is paid; onboarding is still DEBUG-only; the outside-Ukraine sheet shows on every first launch regardless of location or repeats while outside; outside Ukraine still pins Kyiv city when a previous region exists; Manage Subscription shows to non-subscribers
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Build the four DS-3 screens and the owner's behavior changes: onboarding as the
real first-launch screen, About free/Pro, Paywall with loading/plans/error/
empty/subscribed, and the Outside Ukraine sheet on leaving Ukraine.

## Sources

`docs/design/redesign/screens-onboarding-about-paywall.md` (spec, rulings Q1–Q3,
O1–O4); PNGs `onboarding.png`, `about.png`, `about-pro.png`, `paywall-*.png`,
`outside-ukraine.png`; AX5 and Reduce Transparency in `states/`.

## Behavior

- First launch: Onboarding → Get Started → Home.
- Outside Ukraine (REQ-REGION-008): keep the last selected region (Kyiv city
  only if none); sheet when location changes inside → outside, and once at
  launch if already outside; not again while outside; "Choose Region" opens
  Regions.
- Paywall: yearly plan first and preselected; subscribed state with Manage
  Subscription as primary; error and empty distinct; "status stays free" chip.

## Tests

- REQ-REGION-008 tests for the sheet trigger and region retention (inside →
  outside, launch outside, staying outside, no previous region).
- `PaywallViewModelTests`: plan order and preselection, subscribed state,
  error vs empty.
- Snapshots for each screen state. Name tests with REQ IDs.

## Acceptance

Screenshots next to the DS-3 PNGs; `just verify` passes.

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
