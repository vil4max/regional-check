# Stale Live Activity and widget (3.1.0 build 2)

Assignee: Drive Check session (plan `curried-booping-wand`)
State: done; `tf-3.1.0-2` on `b670b67`, TestFlight workflow run `35854804250` succeeded; device checklist with the owner
Requested by: owner (direct, 2026-09-23); path (a) chosen for 3.1.0 build 2, plan approved in session the same day
Requirements: REQ-REFRESH-006 (`docs/requirements/refresh-policy.md`), REQ-SURF-003 and REQ-SURF-009 (`docs/requirements/surfaces-and-pro-gating.md`), REQ-PROVIDER-002 (`docs/requirements/aerial-alerts-provider.md`); the amendments are dated 2026-09-23
Acceptance specs: `WidgetPresentationAccentTests`, `LiveActivityStaleDateTests`, `LiveActivityLifecycleTests`, `LiveActivityRefresherTests`, `WidgetTimelineBuilderTests`
Out of scope: path (b), scheduled local notifications (needs a `core.md` amendment, "not notifications"); a push server; turning the widget's `RefreshStatusIntent` into a `LiveActivityIntent`
Failure conditions: a stale alarm on the Lock Screen looks like a fresh one; a Refresh tap on the Live Activity opens the app, starts a second activity or fetches inside the in-process REQ-REFRESH-010 floor; a failed Refresh ends the activity; a confirmed all-clear seen by Refresh leaves it on screen

## Problem

The owner saw a red "Alert Active" Live Activity on the Lock Screen after the alert had ended;
opening the app showed no alert. The app has no push, no background mode and no BGTask, so while
it is not running nothing can change the activity. `LiveActivityLifecyclePolicy` ends it only on
a confirmed all-clear, and a stale alarm rendered exactly like a fresh one: `liveActivityAccent`
returned `.alert` and the presentation had no footer.

Apple: a `LiveActivityIntent` is performed in the app process without opening the app
(`AppIntents/LiveActivityIntent`), so a button on the activity can re-check without a server. A
Live Activity cannot use the network itself, and iOS flips it to stale at the stale date the app
sets.

## Decisions

- The stale date moves from `checkedAt + 2 × 60 s` to `checkedAt + 15 min`. In the foreground and
  in CarPlay the app still passes its own 2× stale flag, so only the background horizon changes.
  Trade-off accepted: in the background a red activity shows no marker for up to 15 min after its
  last check.
- A stale alarm stays red (REQ-REFRESH-009) and gains the footer "May be outdated. Open the app."
- The Refresh button uses a new `RefreshLiveActivityIntent`, which goes through the app's own
  `StatusController.refresh` and `LiveActivityController`, so the manual-refresh rules (the
  in-process floor, no 429 hold per REQ-REFRESH-005) and the lifecycle policy apply unchanged.
- The widget's refresh stays an extension-side `AppIntent`. Moving every widget tap into an app
  launch would change a path that works today (rejected for build 2 as regression risk).
- The expired widget tier replaces its "Last known" caption with "Open the app to update" rather
  than adding a line; the small widget has no spare height.

## Writer steps

1. `docs(requirements)`: this brief and the four requirement amendments.
2. Stale alarm marker: footer decision in DriveCheckKit, rendered on the Lock Screen and in the
   expanded Dynamic Island, en/uk/ru copy, tests.
3. Stale date 15 min: `LiveActivityStaleDate` and its tests.
4. Refresh button: `RefreshLiveActivityIntent` in DriveCheckKit, an app-side refresher registered
   with `AppDependencyManager`, the button on the Lock Screen and in the expanded Dynamic Island,
   tests.
5. Widget expired copy: the expired tier's caption, en/uk/ru copy, tests, affected baselines.
6. `build(release)`: `CURRENT_PROJECT_VERSION` 2, release notes and device checklist, then
   `tf-3.1.0-2` under the standing tf-tag rule.

Each step lands on `main` after `just verify` and a defect-first review, and is pushed (round
authorization, owner, 2026-09-23).
