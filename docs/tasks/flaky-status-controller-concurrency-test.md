# Agent Task — Make the StatusController concurrency tests load-independent

Assignee: drivecheck-release, starts after RD-1 `READY`
State: open
Requested by: owner (direct, 2026-09-17, ruling Q19 in `docs/tasks/redesign.md`: "да", yes). Owner approval (wave 1): "утверждаю" (I approve), owner direct, 2026-09-17, in drivecheck-product, answering "утверждаете роадмап и запуск волны 1?" (do you approve the roadmap and the wave 1 launch?). Delegated by drivecheck-product.
Evidence: —
Parent: `docs/tasks/redesign.md` (wave 1)
Requirements: `docs/requirements/refresh-policy.md` (status refresh and cancellation behavior)
Changes a requirement: no. If a real defect is found, stop and report to drivecheck-product before any production change.
Owned files: `RegionalCheckTests/StatusControllerConcurrencyTests.swift`, test support files it uses, this brief's findings (reported by message)
Out of scope: `RegionalCheck/Views/StatusController.swift` and any production code (unless the owner approves a fix), `scripts/build-slot.sh`, `BUILD_SLOTS`, other tests
Failure conditions: the time limit is raised or removed to make the test pass; the test is disabled or skipped; the test passes only when the machine is idle; production behavior changes without owner approval
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1).
Xcode MCP: follow the "Xcode MCP" scheduling note in `docs/tasks/redesign.md` §12 (own worktree only, never the primary checkout; revert Xcode metadata drift; `just verify` stays the gate).

## Why

On 2026-09-17, with load average 132 from parallel sessions,
`awaitStatusSettled_whenWaitingTaskIsCancelled_returnsBeforeRefreshSettles`
hit its `.timeLimit(.minutes(1))` in a docs-only branch and passed in 19 s on
the rerun. Later the same day, while RD-1, RD-3 and DS-1 were building,
`mapAppear_duringStatusRefresh_requestsMapOnlyAfterStatusSettlesAndDelay` in
the same suite hit the same 60 s limit in this docs-only branch. Treat all
`.timeLimit` tests in `StatusControllerConcurrencyTests` as in scope. Every lost `just verify` run costs a slot in the one-at-a-time
queue (`docs/engineering/agent-workflow.md`, "Build slots") for all
sessions.

## Research first

1. Read the test and `StatusController` cancellation path; find what the test
   waits on (real sleeps, wall-clock delays, polling, actor hops).
2. Reproduce under load: run the test repeatedly while a build runs in
   another worktree (or with CPU stress) and record timings.
3. Decide: test timing problem (fixable in the test) or a real hang or ordering
   defect in production code (report, do not fix).

## Required behavior

- The test proves the same contract as today: a cancelled waiter returns
  before the refresh settles.
- It no longer depends on wall-clock speed: controllable clock, explicit
  continuations, or awaited signals instead of sleeps.
- The 1-minute time limit stays.

## Acceptance

- For every `.timeLimit` test in the suite: 20 consecutive passes while another `just verify` or build runs in
  parallel; command and timings in the report.
- `just verify` passes; `READY` to `drivecheck-integrator` (branch, SHA,
  worktree, this brief, verify result, `release-prep: no`).
- Report to drivecheck-product: root cause, change, evidence.

Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`,
"Build slots"). `just verify`, `just build`, `just test` wait for a slot; run raw
`xcodebuild` as `./scripts/build-slot.sh run xcodebuild …`; for Xcode MCP use
`just build-slot acquire <label>` and `just build-slot release <token>`. Expect
to wait; never stop another session's run; do not raise `BUILD_SLOTS`.
