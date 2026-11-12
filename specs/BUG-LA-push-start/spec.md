# BUG-LA-push-start: the server's push does not start the Live Activity

Status: approved by the owner with the plan on 2026-11-12 ([plan.md](plan.md)). Ships as 3.3.1.

## Request

Owner, 2026-11-12 (verbatim): «лайвактисвити запускается только после открыия апп на карплей».
Owner's choice the same day: this bug goes first, before the Live Activity, CarPlay and Siri specs.

## Goal

When an alert starts in the driver's region, the Live Activity appears on the Lock Screen, in the
Dynamic Island and on the CarPlay Dashboard without opening the app, as ALERT-push AC-3 promised
for 3.3.0. The fix is proven on a real device, not only by unit tests.

## What is known

- ALERT-push AC-2/AC-3 are implemented: the app reports its push-to-start token
  (`LiveActivityController`, `LiveActivityPushRegistrar`), and drivecheck-api sends `start` on a
  confirmed alarm (`src/push/alarm.ts`, `src/push/liveActivity.ts`).
- The `start` request matches Apple's documented format: `apns-push-type: liveactivity`, topic
  `<bundle id>.push-type.liveactivity`, `event: start`, `alert`, `attributes-type`, `attributes`,
  `input-push-token: 1`, and a `content-state` that matches `ContentState` field for field
  ([Starting and updating Live Activities with ActivityKit push notifications](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)).
- **No real send to a device was ever made.** drivecheck-api spec 004, Group 0 (T001, T002) is
  still open; the server went live without it.
- Opening the app on CarPlay starts the activity from the app (`startIfNeeded`, a CarPlay session),
  which hides whether the push path works.

## Hypotheses (each is closed by evidence, not by reasoning)

- **H1** The device runs a build without push-to-start (App Store 3.2.x rather than TestFlight
  3.3.0 build 129).
- **H2** No server record exists for the device: the app sends the record only with a
  location-confirmed region (`pushEligibleRegion`), Live Activities on in Settings and in iOS, and
  a push-to-start token (`LiveActivityPushRegistrar.performSync`).
- **H3** The server does not send `start`: the alarm was not "confirmed" (cold start, or a gap of
  more than 10 minutes since the previous clear status, server AC-5), or the device's region code
  maps to another region.
- **H4** APNs rejects the request (status and reason in the Worker log), for example a wrong
  environment or topic.
- **H5** APNs accepts it, but iOS does not start the activity (budget, payload decode failure,
  device setting); evidence in `liveactivitiesd`, `apsd` and `chronod` device logs.
- **H6** iOS starts it and the app ends it on its background wake (lifecycle policy, an
  `isRunning` race or `canRunActivity` false at launch); evidence in the app's `LiveActivity` log.

## Evidence per hypothesis (AC-1)

| Hypothesis | Status | Evidence |
| --- | --- | --- |
| H1 build without push-to-start | ruled out | App Store 3.3.0, released 2026-11-11 (public lookup); the owner runs it |
| H2 no server record | **confirmed on the simulator** | 2026-11-12 13:12: the Debug build logged `live activity record not sent (HTTP 400)`. Its push-to-start token is 256 hex digits; drivecheck-api accepts at most 200 (`src/push/registration.ts:17`, `/^[0-9a-f]{1,200}$/i`), so `PUT /v1/push/live-activity` answers 400 and no record exists. The 64-digit notice token passes, which is why the notice arrives. The iPhone's token length is not observed yet (T006) |
| H3 server does not send `start` | open | Needs T005 (log of the push kind) |
| H4 APNs refuses | open | Tail running since 2026-11-12 (`push refused: …`) |
| H5 iOS does not start it | open | T004 spike on the simulator; device logs in T001 and T006 |
| H6 the app ends it on wake | open | T006 (app `LiveActivity` log: `reconcile: endOrphans` or `terminate`) |

## Acceptance criteria

- **AC-1** The root cause is named with evidence: a Worker log line, an APNs answer, a device log
  line or a failing test. Each hypothesis is marked confirmed or ruled out with its evidence.
- **AC-2** A bug in the app or the server first gets a failing test that reproduces it, then the
  fix (project rule: a bug starts with a failing test).
- **AC-3** On a real device with the fixed build, the app not running and not opened: a `start`
  push shows the red activity on the Lock Screen, then an `update`, then an `end` shows it green
  and removes it after 5 minutes. Recorded with times and screenshots in the task's artifacts.
- **AC-4** The same activity shows on the CarPlay Dashboard (CarPlay Simulator or a car) without
  opening Drive Check on CarPlay.
- **AC-5** A runbook in `docs/operations/` lets anyone repeat the check: sending an ActivityKit
  payload to a simulator or a device through APNs sandbox (Apple's Push Notifications Console;
  `xcrun simctl push` cannot send Live Activity pushes; amended by the owner, 2026-11-12), and the
  `log stream` predicates for
  `liveactivitiesd`, `apsd`, `chronod` and the app's `LiveActivity` and `Push` categories.

## Out of scope

- New Live Activity content or design (the Live Activity spec that follows).
- A server deploy: any server fix ships only on the owner's approval.

## Owner's answers (2026-11-12)

1. Build: the App Store release 3.3.0 (owner, corrected the same day). The public lookup
   (`itunes.apple.com/lookup?bundleId=vil4max.RegionalCheck`) shows 3.3.0 released on
   2026-11-11T18:51:48Z. **H1 is ruled out, and the bug is in production.**
2. The alert-start notice arrived; the Live Activity did not appear until the app was opened
   (owner: «пуши приходят, но не запускают лайвактивити - для этого нужен открыть апп»). The server
   therefore saw a confirmed alarm; `start` is queued in the same transaction as the notice
   (`alarm.ts` `poll`), but only for a device that has a Live Activity record (H2).
3. Live Activities are on in the app's Settings tab and in iOS Settings.
4. Read-only access to the Worker logs is granted; no deploy, no server change. A `wrangler tail`
   filtered to `push` runs from this session; its output is kept under the dev-bank task
   `2026-11-12/drivecheck-la-push-start/work/`.

## Static review (2026-11-12): nothing found yet

- Server: `takeOutbox` sends `la-start` to the start token, `resolve` keeps it while the region is
  in alarm, `sendBatch` gets the latest fresh snapshot (`worker.ts`), and a refused request logs
  `push refused: <status> <reason>`. The batch log does not say which kind it sent, so the tail
  tells "sent" from "refused" but not a start from a notice.
- App: the lifecycle policy holds a push-started activity on the background wake; an early `idle`
  phase leaves it alone. Not excluded: the app's own first refresh after the wake reads `quiet`
  from a feed that lags the server's, and ends the activity green as an all-clear (H6).
