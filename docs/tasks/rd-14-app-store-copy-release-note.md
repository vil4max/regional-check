# Agent Task — RD-14: App Store copy and 3.0 release note (docs draft only)

Assignee: drivecheck-product (writes the docs) with input from drivecheck-qa
State: open
Requested by: owner — conditional waves 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "waves 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: REQ-SURF-002, REQ-PROVIDER-003
Changes a requirement: no
Owned files: `docs/operations/app-store-copy.md`, the 3.0 release note under `docs/operations/releases/`, `CHANGELOG.md`, App Review notes draft
Out of scope: App Store Connect, every tag (`tf-3.0.0-N` and `v3.0.0`), submission, build numbers in App Store Connect (all owner-only)
Failure conditions: copy sells the app as an "alert monitor"; the release note appends to the old 3.0 text instead of rewriting it; any App Store Connect or tag action
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Rewrite "What's New", App Store copy and the 3.0 release note for the redesign,
update the changelog, and collect App Review notes (CarPlay map source, not
navigation; paywall; onboarding claims) for the owner.

## Acceptance

Docs landed; owner-only steps listed for the owner summary in the order ADR
0013 (one build pipeline) now requires: mark the old 3.0.0 candidate build "do
not submit", upload screenshots, `just tf-check` then a `tf-3.0.0-N` tag whose
build number is above that old candidate, check the build in TestFlight, submit
that build in App Store Connect, and only then tag `v3.0.0` on the same commit.
A `v` tag no longer requests a build and is created only after submission, so
the "move `v3.0.0`" step from the earlier plan does not exist any more — the
existing `v3.0.0` on 55621e5 marks a build that was never submitted, and what
happens to it (deleted, or left as history) is an owner decision listed in the
summary.

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
