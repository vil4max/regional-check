# Task — requirement trace and brief lint in the verification gate

Assignee: kit-audit desktop session
State: claimed
Requested by: owner (direct, 2026-09-20)
Evidence: pending
Depends-on: none

## Current status and authorization

Current outcome: implemented and verified on `chore/trace-gate` in
`.claude/worktrees/trace-gate`; `READY` for the integrator.
Authorized scope: owner, direct, 2026-09-20: wire the kit's
`spec_trace.py --approved-only` and `brief_lint.py` into this repository's
`just verify`. No test or product code change, no push, no merge; the branch
stops at `READY` for the integrator.
Blocking decisions: none.
Permitted deviations: `--results` is a separate command, not part of
`just verify` (see "Decisions").
Material assumptions: none open; the results join was checked against a real
bundle from this repository.
Next step: integrator lands the branch; a follow-up moves the two comment-only
REQ citations (REQ-REGION-004, REQ-SURF-002) into `@Test` display names.
Requirements: none — this task changes the gate, not product behavior.
Acceptance specs: `scripts/tests/spec-trace-contract.sh`.
Owned files: `scripts/spec-trace.sh`, `scripts/tests/spec-trace-contract.sh`,
`justfile` (`verify`, `trace`), `docs/engineering/testing-strategy.md`
("Measuring REQ coverage"), `AGENTS.md` ("Definition of Done"), this brief.
Out of scope: test sources, requirement documents, other sessions' briefs, CI
workflows, the Runtime under `Tooling/`.
Failure conditions: a trace that skips silently; a trace failure that still
leaves fresh Runtime release evidence; results taken from an unidentified
bundle; brief lint failing the gate for briefs owned by live sessions.

## Decisions

- The trace runs before the Runtime gate. It needs no build slot, and the
  Runtime records release evidence at the end of its own run, so a trace that ran
  afterwards could fail while `just release --check` still passed.
- `--results` stays an explicit command. The Runtime does not pin a result bundle
  path; "newest bundle in DerivedData" can belong to another worktree or a
  partial run, and a bundle still being written is unreadable.
- Brief lint reports and never fails: 24 problems exist today across 41 briefs,
  most in briefs owned by other sessions.
- The tools are resolved from the sibling kit checkout, not vendored. On CI the
  command prints `SKIPPED` and exits 0; `TRACE_REQUIRE_KIT=1` makes a missing kit
  fail. Vendoring was rejected for now: it buys a CI gate at the cost of a second
  copy to keep in step.

## Untested scope

- CI behavior is covered only by the missing-kit contract case; no workflow run.
- `--results` against an `.xcresult` bundle path was exercised through the
  kit's own contract test and, here, through exported JSON from a real bundle;
  not through `just verify`.

## Evidence history

- 2026-09-20, `chore/trace-gate` on `bb330a7`: `just trace` → requirements 33,
  covered 33, uncovered 0; briefs 41, problems 24. `just trace --results` with
  JSON exported from a completed local bundle (329 test cases, all passed) →
  passed 30, failed 0, not_run 3, exit 1 as designed. REQ-REGION-004 and
  REQ-SURF-002 are cited by comment only. REQ-REFRESH-010 is cited in a
  display name; it read `not_run` because the bundle had been produced in the
  `chrome-defects` worktree, whose branch predated that test. An earlier
  version of this record wrongly called all three comment-only; the integrator's
  review caught it.
  `scripts/tests/spec-trace-contract.sh` PASS.
- 2026-09-20, same branch: `just verify` exit 0 — the trace ran first
  (33 of 33 covered), then the Runtime gate reported `verify OK (DoD)`; the
  working tree held only this task's files afterwards, so the formatter rewrote
  nothing.

## Current checklist

- [x] Wrapper, recipes, contract test, documentation
- [x] `just verify` in the worktree
- [ ] `READY` sent to the integrator
