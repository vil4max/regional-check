# Agent Task — RD-17: Release check — regression checklist and TestFlight round

Assignee: drivecheck-qa (after RD-1 … RD-16 land)
State: open
Requested by: owner — conditional waves 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "waves 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: all approved requirements (spot checks by REQ ID)
Changes a requirement: no
Owned files: `docs/operations/` checklist text is written by drivecheck-product from the report; test evidence and screenshots in the report
Out of scope: App Store Connect actions, TestFlight distribution to external testers, tags, the owner's personal devices
Failure conditions: a regression is found and not reported; a check is claimed without evidence; the owner's iPhone is used
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Prove the release candidate on `main` works end to end before screenshots and
the tag.

## Behavior

- Draft the regression checklist (Status, Regions, map, CarPlay tabs and map,
  widgets, Live Activity, Siri, Pro purchase/restore/loss in StoreKit testing,
  onboarding, outside Ukraine, cold start) mapped to REQ IDs.
- Run it on simulators (iPhone and, where available, CarPlay); record results.
- Confirm the latest `main` commit reached `testflight` via green CI; internal
  TestFlight feedback is the owner's step.

## Acceptance

Checklist with pass/fail per item and evidence; open issues filed to
drivecheck-product; `just verify` passes.

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
