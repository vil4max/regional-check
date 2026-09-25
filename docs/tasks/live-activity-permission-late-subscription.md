# Task — Can Details miss a Live Activities Settings change at subscription time?

Assignee: unassigned
State: open
Requested by: owner (direct, 2026-09-25)
Evidence: —
Depends-on: none
Parallelism: none
Profile: fix
user-visible: none

## Current status and authorization

Current outcome: not started. The question comes from reading the code during FLAKY-LA; nothing has reproduced it.
Authorized scope: on 2026-09-25 the owner asked to open this task ("да, заведи задачу": yes, open a task). Implementation needs a plan the owner approves.
Blocking decisions: none
Permitted deviations: none
Material assumptions: the per-app Live Activities switch can only be changed in the Settings app, so Drive Check is in the background when it changes, and the gap described below is open only while Details first appears. Check: whether anything changes the setting while the app is in the foreground, such as Screen Time or a configuration profile.
Next step: plan. First decide whether the gap is reachable. If it is not, close this task with that evidence and change no code.
Requirements: REQ-SURF-008 (`docs/requirements/surfaces-and-pro-gating.md`)
Acceptance specs: a test in which the value changes between the initial read and the start of `activityEnablementUpdates`, and Details still ends up showing the new value
Owned files: `RegionalCheck/LiveActivity/LiveActivityPermission.swift`, `RegionalCheck/Views/DetailsViewModel.swift` (`observeLiveActivityPermission`), `RegionalCheckTests/DetailsViewModelTests.swift`
Out of scope: the app's own Live Activity switch; starting or ending activities
Failure conditions: Details can keep showing a Settings state that is no longer true while it stays on screen; the fix adds polling

## Question

`DetailsViewModel.observeLiveActivityPermission()` (`RegionalCheck/Views/DetailsViewModel.swift:50-55`)
reads `areActivitiesEnabled` first and then iterates `enablementUpdates()`.
`SystemLiveActivityPermission.enablementUpdates()`
(`RegionalCheck/LiveActivity/LiveActivityPermission.swift`) subscribes to
`ActivityAuthorizationInfo().activityEnablementUpdates` inside an inner `Task`, so the subscription
begins some time after the read. If the setting changed in that gap, it is not clear whether
Apple's sequence would deliver the change or only later ones. If it would not, Details would show
the stale state until the view appears again. `DetailsView` starts the observation in `.task`
(`RegionalCheck/Views/DetailsView.swift:128-130`), and nothing refreshes it when the app returns
to the foreground.

## Direction (to confirm in the plan)

If the gap is reachable, read the value again once the subscription exists, for example by
yielding a fresh `areActivitiesEnabled` from inside the inner `Task` right after the iteration
starts. Otherwise, or in addition, refresh when the scene becomes active. Check Apple's documentation
of `activityEnablementUpdates` for whether it replays the current value.

## Writer steps

- [ ] Evidence whether the gap is reachable (documentation plus a test double of the late subscription): a failing test, or a recorded reason to close
- [ ] A fix only if the gap is reachable: `just verify`

## Evidence history

- 2026-09-25: opened from the FLAKY-LA writer's note (`docs/tasks/flaky-live-activity-permission-test.md`, Evidence history).
