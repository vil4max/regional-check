# Agent Task — RD-12: Accessibility pass

Assignee: drivecheck-qa (after RD-5…RD-10 and RD-16 land)
State: open
Requested by: owner — conditional waves 4–5 approval ("если 2-3 пройдут без проблем - утверждаю и отсальные"), after waves 2–5 approval: "утверждаю волны 2–3, список эскалации ок, передай продакту + добить весь объем там не много осталось" and, to the follow-up, "Волны 2–5" (approve waves 2–3, the escalation list is fine, pass it to the product agent, finish the whole scope; waves 2–5), owner direct in drivecheck-integrator, 2026-09-17, relayed at the owner's request. Delegated by drivecheck-product.
Evidence: —
Gate: starts only after the "waves 2–3 without problems" gate passes (owner: "если 2-3 пройдут без проблем - утверждаю и отсальные", 2026-09-17, relayed at the owner's request).
Parent: `docs/tasks/redesign.md`
Requirements: REQ-LAUNCH-005, REQ-SURF-002
Changes a requirement: no
Owned files: small accessibility fixes (labels, traits, grouping, Dynamic Type layout) in views changed by the redesign; accessibility tests and snapshots; report of findings
Out of scope: redesigning layouts, new features, tokens (request changes through drivecheck-product)
Failure conditions: a status is conveyed only by color; VoiceOver reads the segment bar instead of the country line; text truncates at AX5; Reduce Motion or Reduce Transparency ignored; icon-only buttons without labels
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1). The owner is away; drivecheck-product decides within the brief and records assumptions.
Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`, "Build slots"). `just verify`, `just build`, `just test` wait for a slot; raw `xcodebuild` via `./scripts/build-slot.sh run xcodebuild …`; Xcode MCP via `just build-slot acquire <label>` / `just build-slot release <token>`. Never stop another session's run; do not raise `BUILD_SLOTS`.
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).
Docs: only drivecheck-product writes `docs/`; send findings and proposed text in the report.

## Objective

Audit and fix accessibility across the redesigned app per
`docs/tasks/redesign.md` §11 and `states.md` rows 7, 8, 11.

## Behavior

VoiceOver hero reads "{status}, {region}, updated {time}"; round buttons and
map images labeled; AX5 layouts scroll; Reduce Motion and Reduce Transparency
respected; contrast of captions on surfaces ≥ 4.5:1.

## Acceptance

Accessibility Inspector audit output before and after; fixes listed with
screenshots; `just verify` passes.

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
