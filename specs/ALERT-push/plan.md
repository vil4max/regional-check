Base: 9d290890c3f6ad735ce602fba4edd1d9db7e85c7

# ALERT-push: plan

Spec: `specs/ALERT-push/spec.md`. Branch `claude/alert-push` (from `claude/details-compact`, PR 27 not
yet merged). The server half lives in drivecheck-api (its own session); this plan fixes the
contract it must implement and the app side.

## Business rules (read first)

| Rule | Source |
|---|---|
| One switch covers alert-start and all-clear notices | owner, 2026-11-10 |
| Alert-start notice is time-sensitive; all-clear is normal | owner, 2026-11-10 |
| Push starts the Live Activity in red; updates every 5 min while the alarm lasts; green at all-clear, then removed | owner, 2026-11-10 (spec Request) |
| A Live Activity must not hang stale after an all-clear the app missed | owner, 2026-11-10 (AC-9) |
| Only a confirmed change on a fresh feed acts; stale, failing or unknown changes nothing | REQ-SURF-009, REQ-PUSH-002 |
| Gap rule: a change counts only if the previous confirmed status was seen at most 10 min earlier | owner, 2026-11-09 (ALLCLEAR-push point 1) |
| Live Activity runs only while the Details switch and iOS allow it | REQ-SURF-008 |
| Token, region, env, lang, last-seen; 60-day expiry; weekly refresh | REQ-PUSH-001, -006 |
| ActivityKit push: `apns-push-type: liveactivity`, topic `vil4max.RegionalCheck.push-type.liveactivity`, `event` start/update/end, `stale-date`, `dismissal-date`, priority 5 outside the budget, start needs `alert` + `attributes-type` + `attributes` | Apple, "Starting and updating Live Activities with ActivityKit push notifications" (read 2026-11-10) |

Green activity removal: 5 minutes after the all-clear (owner, 2026-11-10).

## Acceptance criteria and blast radius

AC-1..AC-9 of the spec. Blast radius, app: `RegionalCheck/Push/*` (registration gains Live Activity
tokens), `RegionalCheck/LiveActivity/LiveActivityHosting.swift` (request with `pushType: .token`,
expose `pushTokenUpdates`), `LiveActivityController.swift` (send update tokens, end duplicates),
`AllClearPushSwitch.swift` (title), entitlement (time-sensitive), String Catalog, docs (core, REQ-PUSH,
REQ-SURF-009, privacy, release note). Server (drivecheck-api, separate PR): registration fields,
alarm-start detection, LA start/update/end pushes, a 5-minute update loop. Must not touch: CarPlay,
widgets, the refresh policy, StoreKit. Risk class: **high** (permissions, a public contract,
a new entitlement).

## Baseline

Commit `9d290890c3f6ad735ce602fba4edd1d9db7e85c7` (DETAILS-compact head). `ios-verify --base HEAD`:
PASS, 524 tests, 0 failed (`build/verify/baseline.log`).

## Code facts

- `DriveCheckActivityAttributes.ContentState` = `phase` (`idle|quiet|alarm|error`), `regionTitle`,
  `checkedAt: Date?`, `sourceLabel`, `isStale` (`Packages/DriveCheckKit/.../DriveCheckActivityAttributes.swift`).
  Default `Codable`, so the server sends `checkedAt` as seconds since 2001-01-01.
- The app requests activities with `pushType: nil` (`LiveActivityHosting.swift:34-39`), so the
  server cannot end them: the cause of the stale activity the owner saw (AC-9).
- The controller adopts survivors and ends extras only while it holds none (`LiveActivityController.swift:150-157`).

## Approach

One approach for the app (push-to-start and update tokens are Apple's only route to start and end
an activity from the server); the server loop options are for the server session.

1. **Contract** (shared), as built after the owner's point 2 answer (a): the Live Activity record is
   separate from the notice registration and keyed by the push-to-start token.
   `PUT /v1/push/live-activity` `{ startToken, region, env, lang, activityToken? }` (tokens hex,
   `activityToken` absent while no activity runs) and `DELETE /v1/push/live-activity { startToken }`.
   The server keeps one record per start token; a new start token replaces the old record, which the
   app deletes. The notice registration (`/v1/push/registration`) is unchanged.
2. **App**: `LiveActivityPushRegistrar` receives the push-to-start token, the held activity's update
   token and the allowed state from `LiveActivityController` (a `LiveActivityTokenSink`) and keeps the
   record while Live Activities are allowed, whatever the notice switch; the host requests every
   activity with `pushType: .token`; the controller holds every new activity (own, adopted or
   push-started), forwards its update token and ends a second one (AC-7).
3. **Server** (drivecheck-api, its own PR): on a confirmed alarm → time-sensitive notice + LA `start`
   (priority 10) with `attributes-type: DriveCheckActivityAttributes`, red content, `stale-date`
   = `checkedAt` + 15 min (point 5), `input-push-token: 1`; every 5 min while alarm → LA `update` (priority 5, new
   `checkedAt`, `stale-date`); on confirmed all-clear → LA `update` green, then `end` with the green
   content and `dismissal-date` = now + the agreed delay, + the all-clear notice.

## Files and types

- `RegionalCheck/Push/LiveActivityPushRegistrar.swift`: `LiveActivityPushRecord`,
  `LiveActivityPushSending` and its URLSession client, `LiveActivityTokenSink`, the registrar.
- `RegionalCheck/LiveActivity/LiveActivityHosting.swift`: `pushType: .token`; `LiveActivityHandle`
  gains `pushTokens() -> AsyncStream<Data>`; host gains `pushToStartTokens() -> AsyncStream<Data>`.
- `RegionalCheck/LiveActivity/LiveActivityController.swift`: forwards the held activity's tokens to
  a `LiveActivityTokenSink` (the push controller); ends extra survivors.
- `RegionalCheck/Resources/RegionalCheck.entitlements`: `com.apple.developer.usernotifications.time-sensitive`.
- `AllClearPushSwitch.swift` + catalog: title "Notify me about alerts in my region", caption unchanged.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 | `ALERT-push AC-1 one switch title and caption` | key present in en/uk/ru; old all-clear title gone |
| AC-2 | `ALERT-push AC-2 the start token and region are sent only while Live Activities are allowed` | LA allowed (notice switch irrelevant) → PUT carries start token; LA off → DELETE; token change → new token replaces old, old deleted |
| AC-2, AC-9 | `ALERT-push AC-9 every requested activity asks for a push token and its token reaches the server` | host request uses `.token`; fake handle emits token → one `PUT /v1/push/live-activity`; second token → replaces |
| AC-7 | `ALERT-push AC-7 a second survivor is ended and the held activity kept` | held A + push-started B → B ended, A kept; no held + A,B → adopt A, end B |
| AC-6 | existing REQ-SURF-009 controller tests unchanged | stale/failed refresh never ends |
| AC-3..AC-6 (server) | drivecheck-api tests | alarm after clear → 1 notice + 1 start; same alarm next poll → no repeat; 5-min tick → update p5; clear → update green + end + notice; stale feed → nothing; gap > 10 min → nothing |
| AC-8 | strings test + docs | uk/ru present |

## Risks

- Collision audit (read-only):

| Source | Behaviour implied | Scope | Decision that stands |
|---|---|---|---|
| `docs/core.md:43` | "The one allowed push is the opt-in all-clear notice" | product | owner 2026-11-10 widens it; core amended |
| `docs/core.md:25,43` | "Not a monitor", "do not sell as an alert monitor" | product | owner 2026-11-10; wording amended, no marketing as a monitor |
| `specs/ALLCLEAR-push/spec.md` Out of scope | "an alert-start push … Live Activity push updates" | earlier spec | superseded by owner 2026-11-10 |
| REQ-SURF-009 (`surfaces-and-pro-gating.md:199-232`) | the app alone starts and ends the activity; "no server" | Live Activity | amended: the server starts, updates and ends it by push |
| drivecheck-api spec 003 | only all-clear | server | its session amends it |
| privacy policy / App Privacy | token + region only | privacy | add the Live Activity tokens (still device tokens, not linked) |

- Duplicate activities when the app starts one in the foreground and the push starts another: the
  controller ends extras (AC-7); a small window of two visible activities remains.
- Push-to-start needs iOS 17.2+; the app's minimum is iOS 27, so always available.
- APNs budget: start and end at priority 10, the 5-minute updates at priority 5.
- Entitlement: time-sensitive needs the capability on the App ID (Developer portal) before the
  TestFlight build, or signing fails as build 125 did.
- Test host: hosts and streams are faked; no ActivityKit calls in unit tests.

## Tasks

## Group 1: Tokens and registration
- [x] T001 Test: AC-2 start-token tests. Files: `RegionalCheckTests/PushRegistrationTests.swift` or a new `AlertPushTokenTests.swift`
- [x] T002 Implement: start token in registration, client endpoints, controller observer. Files: `RegionalCheck/Push/*`
## Group 2: Live Activity
- [x] T003 Test: AC-9 token request and forwarding, AC-7 duplicate ending. Files: `RegionalCheckTests/LiveActivity*Tests.swift`
- [x] T004 Implement: `pushType: .token`, token streams, sink, extra-survivor ending. Files: `RegionalCheck/LiveActivity/*`
## Group 3: Switch, entitlement, docs
- [x] T005 Test + Implement: switch title strings (AC-1, AC-8), time-sensitive entitlement. Files: catalog, entitlements, `AllClearPushSwitch.swift`
- [x] T006 Docs: core, REQ-PUSH (alert start, LA tokens), REQ-SURF-009 amendment, privacy policy, release note, contract note for the server session. Files: `docs/`
## Group 4: Server handoff
- [x] T007 Send the contract and payload formats to the drivecheck-api session; keep this branch in step.
## Group 5: Owner decisions of 2026-11-10 (green for 5 minutes, symbols, region change)
- [x] T008 Test: the app's own all-clear ends with green content and a dismissal 5 minutes later, for a held activity and for a survivor; the REQ-SURF-009 tests that pinned an immediate end change with REQ-SURF-009's amendment (AC-9, AC-11). Files: `RegionalCheckTests/LiveActivityControllerTests.swift`, `LiveActivityRefresherTests.swift`, `LiveActivityPushTests.swift`
- [x] T009 Implement: an all-clear end carries the green content and `.after(now + 300 s)`; turning off and duplicates stay immediate. Files: `RegionalCheck/LiveActivity/LiveActivityController.swift`
- [x] T010 Test + Implement: `DriveCheckActivityPhase.liveActivityGlyph(isStale:)` in DriveCheckKit (siren, siren with clock badge, shield, clock) and the widget extension draws it (AC-10). Files: `Packages/DriveCheckKit/...`, `RegionalCheckWidgets/DriveCheckLiveActivity.swift`
- [x] T011 Docs: REQ-SURF-009 amendment. Files: `docs/requirements/surfaces-and-pro-gating.md`
## Group 6: Calm pushes, the Time Sensitive switch and the system state (owner, 2026-11-10)
- [x] T012 Sound: `scripts/sound/make-notification-sounds.py`, `drivecheck.caf` in the bundle, test (AC-12)
- [x] T013 Test: urgent is sent only with the Time Sensitive and notice switches on, in both PUTs; the Time Sensitive Off row shows only with the switch on and iOS off; a foreground re-reads it; strings are Apple's (AC-13..AC-15). Files: `RegionalCheckTests/UrgentPushTests.swift`
- [x] T014 Implement: `PushPreferenceStore.isUrgent`, `PushRegistration.urgent`, `LiveActivityPushRecord.urgent`, `PushPermissionProviding.timeSensitiveAllowed()`, the controller's `setUrgent` and state, `SettingsOpening.openNotificationSettings()`, the Details rows. Files: `RegionalCheck/Push/*`, `RegionalCheck/Views/AllClearPushSwitch.swift`, `RegionalCheck/App/*`
- [x] T015 Docs: REQ-PUSH notes, App Review note line on time-sensitive opt-in. Files: `docs/`

## Review lows

From the two review rounds, not fixed (owner decides):
- [LiveActivityController.swift `pushUpdate`, LiveActivityLifecyclePolicy.swift:41-43] A stale quiet
  status newer than the activity's check gives `.update`, so a red activity is rewritten to a
  green, stale state and left running instead of staying red (REQ-REFRESH-006, plan point 3).
- [build/verify/red-g5.log] The red log names the failing tests without their failure reasons, and
  the composition-root test and the renamed AC-1/AC-8 strings test were not part of the red run.
- [PushWiringTests.swift `liveActivityTokensAreWiredWithoutAScene`] It checks only the sink
  identity, not a token travelling from the fixture host to a fake client.
- [LiveActivityController.swift `tokenSink.didSet`, `heldTokenIsReplayedToALateSink`] The sink is set
  in `AppContainer.init` before any stream yields, so the activity-token replay covers a path
  production does not reach today.
- Not checked without a device: whether `activityState` is current after the system ends an
  activity while the app is suspended, and whether the background time of a push-to-start wake is
  enough for the registrar's PUT (no `beginBackgroundTask`).

## Verification

`ios-verify` (background), `scripts/spec-trace.sh`; the real test is a TestFlight build with the
time-sensitive capability and the server deployed: alarm → notice + red activity, updates every
5 minutes, all-clear → green, then gone.

## Points to decide

`plan-critic` findings, unchanged, each with my proposed answer:

1. [plan:57-61, LiveActivityLifecyclePolicy.swift:41-45] A push-started activity appears while the
   app is not running or only woken in the background, with phase idle or saved; the policy adopts
   only in `.alarm`, so its update token never reaches the server (AC-4, AC-9). Proposed answer:
   the app watches `Activity<DriveCheckActivityAttributes>.activityUpdates` and sends the update
   token of any new activity whatever the phase; test for an activity started by push in the
   background. Fixed in the plan (T003, T004).
   - Decision: accepted
2. [plan:53-56, PushRegistrationController.swift:142-146] Activity tokens hang off the APNs device
   token, registered only while the notice switch is on, so a driver with Live Activities on but
   notices off still gets a stale activity, against AC-9's "every". Proposed answer: owner decides
   between (a) sending Live Activity tokens whenever Live Activities are on, keyed by the
   push-to-start token, which sends a token and region for drivers who did not switch notices on
   (privacy text widened), or (b) narrowing AC-9 to drivers with the notice switch on.
   - Decision: accepted, option (a)
3. [RegionalCheckApp.swift:42-43, LiveActivityLifecyclePolicy.swift:41-43] On foreground the app
   syncs the saved quiet status before its first refresh, and the policy ends the server's red
   activity as an orphan. Proposed answer: the app ends an alarm activity only on a fresh,
   confirmed all-clear from its own refresh, never on a saved, stale or not-yet-refreshed status;
   test for that case. Fixed in the plan.
   - Decision: accepted
4. [plan:62-66, LiveActivityContentSync.swift:10-12, DriveCheckLiveActivity.swift:36,
   drivecheck-api src/push/text.ts:8-18] "Red content" leaves out `regionTitle` and `sourceLabel`,
   and the alert-start notice has no wording. Proposed answer: the contract fixes `regionTitle` to
   the app's region names in the driver's language (en, uk, ru table taken from the app catalog),
   `sourceLabel` to the value the app sends today, and the alert-start notice as "Air raid alert:
   <region>" / "Повітряна тривога: <region>" / "Воздушная тревога: <region>"; the server's AC-8
   test checks them. Wording: owner decides.
   - Decision: accepted (wording as proposed)
5. [plan:64, LiveActivityStaleDate.swift:8] The server's `stale-date` +10 min has no source and
   differs from the app's 15-minute horizon (REQ-REFRESH-006). Proposed answer: server pushes use
   the same 15-minute horizon from `checkedAt`. Fixed in the plan.
   - Decision: accepted

Also without a source: how long the green activity stays before removal (`dismissal-date`).
Proposed: 5 minutes. Owner decides.

Owner's answers at this gate (2026-11-10): point 2 option (a), Live Activity tokens go to the server
whenever Live Activities are on, keyed by the push-to-start token, privacy text widened; point 4
wording accepted as proposed; green activity removed 5 minutes after the all-clear; points 1, 3 and 5
accepted as fixed; approach accepted.
