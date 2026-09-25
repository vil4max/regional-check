# Task — Make the REQ-SURF-008 Settings-change test load-independent

Assignee: unassigned
State: open
Requested by: owner (direct, 2026-09-25)
Evidence: —
Depends-on: none
Parallelism: none
Profile: fix
user-visible: none

## Current status and authorization

Current outcome: not started.
Authorized scope: the owner asked on 2026-09-25 to open this task ("yes, create a task"). Implementation needs a plan the owner approves.
Blocking decisions: none
Permitted deviations: none
Material assumptions: the production code is correct and only the test's synchronisation is racy. Check: the failing reproduction under load shows the stream subscribed late or the value read early, not a missed update in `DetailsViewModel.observeLiveActivityPermission`.
Next step: plan. First reproduce the failure under load, for example by running the test repeatedly while the host is busy.
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

- [ ] Failing spec: a reproduction under load, such as repeated runs while the host is busy, shows the failure: the failure is recorded
- [ ] Event-based synchronisation in the fake and the test: `just verify`, and the repeated run under load passes every time

## Evidence history

- 2026-09-25: opened after run 36105381649 failed once and passed on rerun.
