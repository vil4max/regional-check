# Task — Make the REQ-SURF-008 Settings-change test load-independent

Assignee: Drive Check
State: done
Requested by: owner (direct, 2026-09-25)
Evidence: fail — `switchablePermissionHoldsAChangeForALateSubscriber` failed on 86c431b (`delivered → nil`: the old fake drops a change for a subscriber later than 100 yields); verify — `just verify` OK on ce642ed, and under 20 busy-loop processes (host load 400-680) 600 of 600 iterations and a 1000-case concurrent copy passed; review — `/code-review medium`, no findings
Depends-on: none
Parallelism: none
Profile: fix
user-visible: none

## Current status and authorization

Current outcome: both steps landed (86c431b, ce642ed).
Authorized scope: the owner asked on 2026-09-25 to open this task ("yes, create a task"). The plan was approved the same day through AskUserQuestion "FLAKY-LA … Что делаем?", answer verbatim: "Делать сейчас (Recommended)". It covers reproducing the failure under load first, then event-based synchronisation in the fake and the test with a clock deadline, no production change, and two commits, after SNAP-VER.
Blocking decisions: none
Permitted deviations: none
Material assumptions: the production code is correct and only the test's synchronisation is racy (held: no production defect was reproduced). Check: the failing reproduction under load shows the stream subscribed late or the value read early, not a missed update in `DetailsViewModel.observeLiveActivityPermission`.
Next step: none.
Requirements: REQ-SURF-008 (`docs/requirements/surfaces-and-pro-gating.md`)
Acceptance specs: `LiveActivitySwitchTests` "REQ-SURF-008 turning Live Activities off in Settings while Details is open is picked up"
Owned files: `RegionalCheckTests/DetailsViewModelTests.swift` (the test and `SwitchablePermission`)
Out of scope: `RegionalCheck/Views/DetailsViewModel.swift` and any production code, unless the reproduction shows a real defect, in which case stop and report; other flaky tests (`docs/tasks/flaky-status-controller-concurrency-test.md`)
Failure conditions: the test is disabled, skipped or retried to pass; the fix only raises an iteration count; it still depends on how many times the scheduler runs other tasks

## Problem

Tests on `main` failed once on 2026-09-25 (run 36105381649, commit `3da6c73`, docs only) with
`Expectation failed: sut.isLiveActivityAllowedBySystem == false` in
"REQ-SURF-008 turning Live Activities off in Settings while Details is open is picked up". The test
took 5.4 s, and the rerun of the failed job passed. The same test passed on `a2f3582` just before.

Both sides wait by counting scheduler turns rather than by an event:

- `SwitchablePermission.change(to:)` (`RegionalCheckTests/DetailsViewModelTests.swift:146`) yields
  at most 100 times for a subscriber, then sets `current` and yields to a continuation that may
  still be `nil`. On a loaded runner the observation task may not have called
  `enablementUpdates()` yet, so the value is set with no subscriber to receive it.
- The test (`:112`) yields at most 100 times for `isLiveActivityAllowedBySystem` to turn false,
  then asserts, whether or not the update arrived.

## Direction (to confirm in the plan)

Make the fake signal its subscription, for example with an `AsyncStream` or a checked continuation
that `enablementUpdates()` resumes. Deliver the change only after that signal. Then await the view
model's update with a clock-based deadline instead of a count of `Task.yield()` calls. The app's
own `BoundedAwait` (`RegionalCheck/AI/BoundedAwait.swift`, see `BoundedAwaitTests`) is one way to bound it.

## Writer steps

- [x] Failing spec: a reproduction under load, such as repeated runs while the host is busy, shows the failure: the failure is recorded — 86c431b
- [x] Event-based synchronisation in the fake and the test: `just verify`, and the repeated run under load passes every time — ce642ed

## Evidence history

- 2026-09-25: both steps by a `slice-writer` (opus) in its own worktree, landed ff-only. Load alone never reproduced the CI failure (0 of 300 iterations and 0 of 1000 concurrent copies at host load 100-370), so the failing spec is deterministic: a subscriber 100 ms late loses the change with the old fake. The fake now waits for a subscription signal and the test polls against a 5 s `ContinuousClock` deadline.
- 2026-09-25: open question from the writer, not proven: `SystemLiveActivityPermission.enablementUpdates()` subscribes inside an inner `Task` after `refreshLiveActivityPermission()` reads the value, so a Settings change in that gap might be missed until Details next appears. Out of scope here; offered to the owner as a possible task.

- 2026-09-25: opened after run 36105381649 failed once and passed on rerun.

## Reviews

### Round 1 review — flaky-live-activity-permission-test (2026-09-25)

Review SHA: ce642ed
No findings (`/code-review medium`).
