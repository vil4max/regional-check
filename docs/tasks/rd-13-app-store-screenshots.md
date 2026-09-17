# Agent Task — RD-13: App Store screenshots for 3.0.0 (English, local only)

Assignee: drivecheck-qa (after RD-17)
State: open
Requested by: owner — conditional batches 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after batches 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve batches 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; batches 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "batches 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: REQ-SURF-002
Changes a requirement: no
Owned files: `scripts/capture-app-store-screenshots.sh`, `release/screenshots/asc/`
Out of scope: uploading to App Store Connect (owner-only), other locales, marketing text
Failure conditions: any upload or App Store Connect action; screenshots show old design; onboarding shot differs from the real first-launch screen
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Re-capture every `release/screenshots/asc/` shot in the new design, add Regions
search and the full-screen map, and update the capture script phases. English
only. Prepared locally for the owner's review and upload.

## Acceptance

New PNGs at the App Store size in `release/screenshots/asc/`, a contact sheet
in the report, `just verify` passes. Upload stays with the owner.

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
