Base: 4302a802e36358945e879fc01fb282b239275888

# Plan: BUG-LA-push-start, the server's push does not start the Live Activity

Spec: `specs/BUG-LA-push-start/spec.md`. Skill: `/spec-driven-dev:plan`.

## Context

Drive Check 3.3.0 has been in the App Store since 2026-11-11 18:51 UTC (public lookup). Its main
feature, the server starting the Live Activity by push (ALERT-push, REQ-PUSH-008), does not work
for the owner. The alert-start notice arrives, but the Live Activity appears only once the app is
opened on CarPlay, and opening the app starts it locally. The push path was never tested on a real
device: drivecheck-api spec 004, Group 0 is still open. A static review of the app and the server
found no defect. The cause has to be measured, so this plan gets evidence first, then fixes with a
failing test first, then proves the result on a device.

## Business rules (all already sourced)

- The server starts the activity only on a confirmed alarm: a clear status seen at most 10 minutes
  earlier (drivecheck-api spec 004 AC-5, `GAP_MS` in `src/push/changes.ts:6`).
- It updates every 5 minutes, and the green end is dismissed 5 minutes later (owner, 2026-11-10;
  ALERT-push AC-4, AC-9).
- The app reports its start token only while Live Activities are allowed (in the app and in iOS)
  and the region is confirmed by location (`LiveActivityPushRegistrar.performSync`,
  `RegionSelection.pushEligibleRegion`).
- No token, device identifier or region of a user goes into an uploaded log or into the repo
  (AGENTS.md, Data handling). `os.log` stays local diagnostics only
  (`docs/operations/analytics.md`).
- Submitting, `v` tags and server deploys are the owner's.

## Acceptance criteria (spec) and blast radius

AC-1 root cause named with evidence · AC-2 failing test, then the fix · AC-3 real device: start,
update, end, app not opened · AC-4 CarPlay Dashboard without opening the app · AC-5 runbook.

- **May touch:** `RegionalCheck/LiveActivity/*`, `RegionalCheck/Push/LiveActivityPushRegistrar.swift`,
  `RegionalCheck/App/AppDelegate.swift` (launch path), their tests in `RegionalCheckTests/`,
  `docs/operations/` (the new runbook), `docs/requirements/push.md` (only if the cause changes a
  requirement). Server: `drivecheck-api/src/push/*` only if the cause is there, in its own repo and PR.
- **Must not touch:** the `ContentState` shape (a contract with the server payload; changing it
  breaks the live server's pushes), CarPlay and widget UI, version numbers before the release step.
- **Risk class: high.** A public contract (the APNs payload and the server API) and a live production
  feature.

## Baseline

Commit `4302a802e36358945e879fc01fb282b239275888` (main). Gate `ios-verify --base HEAD`: **PASS** in 92 s,
566 tests passed, 0 skipped, 0 failed (`build/verify/baseline.log`).

## Approach

Three ways to get the evidence, used together, cheapest first:

1. **Passive (no code):** the read-only `wrangler tail --search push` already running in this
   session. During the next alert, the owner records the device logs in Console.app for
   `liveactivitiesd`, `apsd`, `chronod` and the `vil4max.RegionalCheck` subsystem. This tells
   "the server sent / APNs refused" from "the device got it and did not start".
2. **Active spike (closes server Group 0 without handling the APNs key in the session):** a Debug
   build on the simulator (not the iPhone, see point 2 below) prints its sandbox push-to-start
   token (Debug only). The owner pastes it into Apple's Push Notifications Console (development
   environment, push type Live Activity) with the server's exact `start` payload, with the app not
   in the foreground. Two variants: the payload as the server sends it, and the same payload with
   an `alert.body` added. This isolates H5 (payload or iOS) from the server and from the
   production record.
3. **App diagnostics for every build:** `Logger` lines with no tokens, in the `LiveActivity` and
   `Push` categories, at each decision point: a push-started activity received, held or ended (with
   the reason), a lifecycle policy action, the record PUT/DELETE outcome (HTTP status only). Without
   them, the device log in 1 shows nothing of the app's side (today `LiveActivity` logs only a
   failed `request`).

Then Group 2 writes the failing test for the confirmed cause and fixes it. Its tasks are named
after Group 1 and come back to the owner as a plan amendment: the cause is not known yet, and
guessing a fix would be a requirement with no source.

## Files and types

- `RegionalCheck/LiveActivity/LiveActivityHosting.swift`: Debug-only start-token print in
  `pushToStartTokens()` (`#if DEBUG`).
- `RegionalCheck/LiveActivity/LiveActivityController.swift`: decision logs in `receiveNewActivity`,
  `reconcileActivity` (the chosen `Action`), `terminate`, `endAllClear`, `endSystemActivities`.
- `RegionalCheck/Push/LiveActivityPushRegistrar.swift`: outcome logs in `performSync` and
  `forget` (status only).
- New `docs/operations/live-activity-push-debugging.md` (AC-5).
- No new types. The log text is fixed English with `privacy: .public` only for enum values and
  HTTP status codes.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 | Evidence record in the task artifacts, no unit test | Tail line `push refused: 4xx <reason>` → H4; `sent` with no activity on the device and an error in `liveactivitiesd` → H5; an activity that the app log shows `ended (allClear)` within a minute of the start → H6 |
| AC-1 (H2) | `PushClientTests`: `REQ-PUSH-008 a refused Live Activity registration reports its HTTP status` | Server 400 → error with 400; 503 → 503; 204 → no error |
| AC-2 | Named in the amendment after Group 1, e.g. `REQ-PUSH-008 a push-started activity survives the app's background wake` | Written for the confirmed cause; it must fail on `4302a80` |
| AC-2 (logs) | `LiveActivityControllerTests`: `REQ-PUSH-008 a held push-started activity is not ended by an older saved quiet status` (existing guard, kept green) | A saved `quiet` with `checkedAt` older than the activity's → no end; newer → green end with 5-minute dismissal |
| AC-3 | Manual device run, recorded | App not running; `start` → red Lock Screen; `update` at +5 min; `end` → green, gone at +5 min |
| AC-4 | Manual CarPlay Simulator / car run, recorded | The activity is on the Dashboard before Drive Check is opened on CarPlay |
| AC-5 | Doc review | The runbook says `xcrun simctl push` cannot send Live Activity pushes (measured 2026-11-12: "Only application remote push notifications are supported") |

The log lines change no behaviour, so they get no new unit tests. The existing suites
(`LiveActivityControllerTests`, `LiveActivityAdoptionTests`, `LiveActivityLifecycleTests`,
`LiveActivityPushTests`) must stay green.

## Risks

- **Collisions:** (1) AGENTS.md "A bug starts with a failing test" against diagnosis first: the
  failing test comes after the cause is known, still before the fix; no conflict once Group 2 is
  amended. (2) `docs/operations/analytics.md`: `os.log` is local only, so the new lines upload
  nothing. Confirmed by that page, no decision needed. (3) ALERT-push spec AC-3 says the server
  starts the activity: the behaviour is unchanged, this restores it. No other collisions found.
- **Privacy:** a start token in a log is a device identifier. It is printed only in Debug
  (`#if DEBUG`) and never committed. The runbook uses placeholders.
- **Lifecycle:** the background wake has no scene. Logs must not force the container or a scene
  (`AppDelegate` already builds the container at launch).
- **Timing:** the passive path waits for a real alert in the owner's region, which nobody can
  schedule. The spike does not wait.
- **Release:** 3.3.0 is live. A fix-only release is 3.3.1 (AGENTS.md Versioning: PATCH). The Live
  Activity, CarPlay and Siri features go to 3.4.0.
- **Server:** if the cause is on the server, its fix is a drivecheck-api PR, and the deploy is the
  owner's.

## Tasks

Terminated states (critic point 4, fixed in the plan): every device run records which one it
used. **S1, suspended:** the app was sent to the background and left. **S2, ended by the system:**
the iPhone was restarted and the app was not opened since. **S3, force-quit:** swiped away in the
app switcher. Since iOS may not wake a force-quit app in the background, S3 can show the activity
without its update token reaching the server. S1 and S2 are the cases that must pass; S3 is
recorded, not required.

## Group 1: evidence (AC-1, AC-5 draft)
- [ ] T001 [Owner + session] Now, on the App Store build, before any other build touches the
  phone (critic point 2): during the next real alert the session reads the tail, the owner captures
  Console.app logs (`liveactivitiesd`, `apsd`, `chronod`), state S1.
- [x] T002 Test: `PushClientTests`: `REQ-PUSH-008 a refused Live Activity registration reports its
  HTTP status` (a 400 or 503 → an error carrying 400 or 503, not a bare `badServerResponse`).
  Files: `RegionalCheckTests/PushClientTests.swift`
- [x] T003 Implement: the client error carries the status; decision logs with no tokens in the
  controller (received, held, ended with the reason, the policy action) and in the registrar (each
  skipped sync with its reason: not allowed, no start token, no confirmed region, unchanged; each
  PUT/DELETE with its status); Debug-only start-token print. Files: `LiveActivityHosting.swift`,
  `LiveActivityController.swift`, `LiveActivityPushRegistrar.swift`
- [ ] T004 [Owner] Spike on the **simulator**, not the iPhone (critic point 2): the Debug build
  with location not granted, so `pushEligibleRegion` is nil and nothing reaches the production
  server. The owner sends the server's `start` payload to the simulator's sandbox token from Apple's
  Push Notifications Console, in two variants (as sent, and with `alert.body`), in S1 and S3. The
  session prepares the payloads and the steps and reads the simulator log. Apple supports
  ActivityKit push to the simulator through APNs sandbox on an Apple silicon Mac
  ([ActivityKit push article](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications#Test-Live-Activity-updates-locally)).
- [ ] T005 [Owner] Server diagnostics for H2/H3 (critic point 1), in drivecheck-api, its own PR:
  one log line per sent push that names its kind and APNs status, and at an alarm start the number
  of Live Activity records queued for the region; no tokens. The deploy is the owner's.
- [ ] T006 [Owner] TestFlight build with T003 on the iPhone (production APNs, production server),
  during an alert: app log, device log and tail together, in S1 and S2.
- [ ] T007 Docs: evidence table per hypothesis in `spec.md`; the runbook draft
  `docs/operations/live-activity-push-debugging.md`. Gate green, one commit.

## Group 2: failing test and fix (AC-2), amended after Group 1
- [ ] T008 Test: <named from the confirmed cause> fails on the baseline.
- [ ] T009 Implement: <the fix>.

## Group 3: proof on a device (AC-3, AC-4) and the runbook (AC-5)
- [ ] T010 [Owner] TestFlight build with the fix; the server's real `start` / `update` / `end` on
  the iPhone with the app not opened, in S1 and S2; the CarPlay Dashboard check. Times and
  screenshots go to `.artifacts/` through `scripts/project-artifacts.py`.
- [ ] T011 Docs: finish the runbook; close spec 004 Group 0 in drivecheck-api with the result
  (its own commit there).

## Review lows
(filled by implement)

## Points to decide

1. Critic: H2 (no server record) and H3 (start not sent) get no evidence from the tail or the App
   Store build. Proposed: T005, server log lines with the kind and the record count (a server PR,
   your deploy), plus T006, the TestFlight build with app logs. Owner decides.
2. Critic: a Debug build on the iPhone would replace the production record with a sandbox one and
   destroy the H2 evidence. **Fixed in the plan:** T001 on the App Store build first, and the spike
   (T004) on the simulator without location, so it never registers with the server.
3. Critic: the client drops the HTTP status, and a skipped sync logs nothing. **Fixed in the
   plan:** T002 and T003 (the error carries the status, each skipped sync logs its reason).
4. Critic: "app closed" was undefined. **Fixed in the plan:** states S1, S2 and S3; S1 and S2 must
   pass, S3 is recorded.
5. Critic: `xcrun simctl push` cannot send Live Activity pushes (measured), so spec AC-5 as written
   cannot be met. Proposed: amend AC-5 to "a payload to a simulator or a device through APNs
   sandbox (Push Notifications Console)". Owner decides.
6. Release: the fix ships alone as 3.3.1 (fix and diagnostics only); the Live Activity, CarPlay and
   Siri features go to 3.4.0.

Decisions (owner, 2026-11-12, plan approved the same day):

1. - Decision: accepted ("Да, server PR")
2. - Decision: accepted («Принимаю»)
3. - Decision: accepted («Принимаю»)
4. - Decision: accepted («Принимаю»)
5. - Decision: accepted ("Да, переписать")
6. - Decision: accepted ("Да, 3.3.1 отдельно")
