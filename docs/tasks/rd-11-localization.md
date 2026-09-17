# Agent Task — RD-11: Localization pass en/uk/ru and wording consistency

Assignee: ios-regions (after the UI tasks RD-5, RD-6, RD-7, RD-8, RD-9, RD-10, RD-16 land)
State: open
Requested by: owner — conditional waves 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "waves 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: REQ-SURF-001 (full and short forms, casing, identical across catalogs)
Changes a requirement: no
Owned files: `RegionalCheck/Resources/Localizable.xcstrings`, the widget and DriveCheckKit catalogs, `RegionalCheckTests/StatusWordingConsistencyTests.swift`, new wording tests
Out of scope: layout changes, new features, keys owned by an unlanded task
Failure conditions: a key lacks uk or ru; full and short forms differ across catalogs; casing rule broken; plural rules missing; `liveActivity.stale` still shows "Updating…" for stale data
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Complete en/uk/ru for every key added by the redesign tasks, reconcile
duplicates, add full status forms, and extend wording tests.

## Behavior

- Full forms (iPhone/CarPlay titles) and short forms (pills, widgets, Live
  Activity, Dynamic Island, Control Center, Siri) per REQ-SURF-001, identical
  in every catalog; casing rule from `geometry-and-tokens.md` §6.
- Plural variations for counts; separate checking vs stale wording.
- Check Control Center and Siri/Shortcuts answers use the short form.

## Tests

`StatusWordingConsistencyTests` extended to full and short forms in all three
locales and catalogs (REQ-SURF-001).

## Acceptance

No missing translations (catalog state all translated); `just verify` passes.

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
