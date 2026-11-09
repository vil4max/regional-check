# ALLCLEAR-push: plan

Spec: `specs/ALLCLEAR-push/spec.md` (this repo). Branch `claude/allclear-push` (from `main`).
The server half lives in drivecheck-api, in its own branch and spec there.

## Business rules (read first)

| Rule | Source |
|---|---|
| Send only on a confirmed alarm → clear change; a failed, stale or unknown refresh never counts as clear | REQ-SURF-009 (`docs/requirements/surfaces-and-pro-gating.md:199-207`) |
| The server may store a device token and a region code | owner decision, 2026-11-09 (spec Request) |
| No accounts, no history, no location on the server | `docs/core.md:41` (Never), owner decision above allows token and region only |
| Every feature stays free | `docs/core.md`, ADR 0016 |
| Free Workers plan: 50 subrequests and 10 ms CPU per invocation | spec spike table (Cloudflare Workers limits page) |
| One status request per 10 s upstream, shared by all clients | drivecheck-api README "Polite to the data source" |

No rule without a source. A message wording is the owner's call (Points to decide).

## Acceptance criteria and blast radius

AC-1..AC-7 of the spec. Blast radius, this repo: new `RegionalCheck/Push/` (permission, token,
registration), `AppDelegate.swift` (remote-notification callbacks), `RegionalCheck.entitlements`
(`aps-environment`), `DetailsView`/`DetailsViewModel` (one switch), String Catalog, tests, docs
(`core.md`, privacy policy, REQ-SURF-009 note, release note). drivecheck-api: a registration
endpoint, an alarm that polls the feed, change detection, APNs sender, storage of token and
region, README "Never". Must not touch: CarPlay, widgets, Live Activity, refresh policy, StoreKit.
Risk class: **high** (permissions, a new data flow off the device, a public contract, a privacy
policy change). The full diff must be read.

## Baseline

Commit `241fb72694b0c75dd2cd33dbde7283dd40680331` (`main`). `ios-verify --base HEAD`: PASS, 495
tests, 0 failed (`build/verify/baseline.log`).

## What exists today (code facts)

- The iOS app never talks to drivecheck-api; it reads the provider directly (no `drivecheck` string in
  `RegionalCheck/` or `Packages/`). A registration call adds the app's first call to our own server.
- No notification code at all (no `UNUserNotificationCenter`, no `aps-environment`).
- `AppDelegate` already exists (`RegionalCheck/App/AppDelegate.swift`), the right place for the
  remote-notification callbacks; the Live Activity switch in `DetailsView.swift:84-101` is the
  pattern for one more opt-in switch.
- drivecheck-api: `FeedCoordinatorObject` fetches the provider only when a client asks
  (`src/coordinator.ts` `current()`); there is no alarm or cron, and only the latest snapshot is kept
  (REQ-API-003).

## Approach

Options, neutral order:

- **A. Durable Object alarm polls the feed** (every 30 s while any device is registered), detects
  alarm → clear, queues pushes in the DO and sends them in batches of at most 45 per invocation,
  chained by alarms. Cost: new alarm loop, a token/region table in DO SQLite, an APNs sender;
  largest change; needs the spike to prove the alarm's CPU limit and APNs access.
  Counterargument: the Durable Object CPU limit on Free is unresolved in the docs (10 ms or 30 s);
  an alarm that overruns would fail on the plan the owner wants to keep free.
- **B. Cron Trigger every minute calls the DO**, which polls, detects and sends in the same way.
  Cost: same storage and sender, no alarm loop, a delay of up to 60 s on top of the provider's;
  Cron Triggers on Free have a 10 ms CPU limit stated on the limits page.
  Counterargument: 10 ms for parse + diff + up to 45 signed requests is tight and unmeasured.
- **C. Only piggyback on client requests** (no alarm or cron): detect the change when any app or
  web visitor happens to fetch. Cost: smallest. Counterargument: nobody may fetch for hours, so
  the push arrives late or never, which defeats the feature.
- **D. Push only to a few devices with an external relay** (a free queue service): not
  evaluated further: it adds a third party that holds tokens, against the privacy rule.

Agent's lean: **A**, fall back to **B** if the spike shows the alarm is limited to 10 ms. The spike
needs the owner's APNs key (never handled by the agent).

## Contract (shared between the two repos)

- `PUT /v1/push/registration` body `{ "token": "<hex>", "region": "<AlertRegion raw value>", "env": "production|sandbox", "lang": "en|uk|ru" }`, answer 204; `DELETE /v1/push/registration` body `{ "token": "..." }`, answer 204.
- The server keeps `token → {region, env, lang, updatedAt}` and nothing else; a token not seen for 60 days is dropped.
- The push text is built on the server from `lang`: "Alert over: <region>" in en, uk, ru (wording: Points to decide).

## Files and types

iOS (this repo): `Push/PushRegistrationService` (protocol seam, ADR 0008), `Push/PushRegistrationStore`
(opt-in state in the App Group defaults), `Push/PushPermission` (`UNUserNotificationCenter` wrapper),
`AppDelegate` callbacks `didRegisterForRemoteNotificationsWithDeviceToken`, `DetailsViewModel`
switch `isAllClearPushOn`. Region changes go through `StatusController.currentRegion`
(`Status/StatusController.swift:92`); the service re-registers when it changes.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 (iOS) | `REQ-PUSH-001 registers token and current region once opted in` | opt-in → one PUT with the region; opt-in without permission → no PUT |
| AC-1 (iOS) | `REQ-PUSH-001 a region change re-registers` | region A → B → one more PUT with B, none when region is unchanged |
| AC-3 | `REQ-PUSH-003 switching off sends DELETE and stops the permission prompt` | off → one DELETE; a later launch does not ask for permission |
| AC-3 | `REQ-PUSH-003 a denied permission leaves the switch off and explains` | permission denied → switch off, hint shown |
| AC-6 | `REQ-PUSH-006 the request body carries only token, region, env, lang` | body keys compared to an exact set |
| AC-7 | `REQ-PUSH-007 strings in en, uk, ru` | every new key has all three |
| AC-1,2,4,5 (server) | in drivecheck-api: change-detection and sender tests | stale feed → no send; alarm→clear → one send; 410 → token deleted; 100 devices → batches of at most 45; the same change twice → one push per device |

## Risks

- Collision audit (read-only):

| Source | Behaviour implied | Scope | Decision that stands |
|---|---|---|---|
| `docs/core.md:25` | "Not a monitor, not notifications" | product definition | none found for a push; owner decides |
| `docs/core.md:41` | Never: accounts, history, "alert monitor" | product | token and region approved 2026-11-09; no account, no history |
| `docs/requirements/surfaces-and-pro-gating.md:226-231` (REQ-SURF-009) | a server with APNs "rejected for now, candidate after 3.0.0" | Live Activity | the owner's 2026-11-09 approval is the later decision |
| `docs/privacy-policy.html:19-20` | location not uploaded; no collection besides listed | privacy | must be amended: a device token and region code are sent to our server |
| `docs/operations/releases/3.0.md:130` | "the app has no server of its own" | release note | history; later note must differ |
| drivecheck-api `README.md` "Never" and REQ-API-003 (`specs/001-.../spec.md:232`) | no personal data, nothing stored about visitors | API | amended by the feature's server spec |
| App Review | a new data flow, a notification permission | release | privacy nutrition label and review notes need the owner (App Store Connect) |

- Rate/cap: 45 pushes per invocation (50 − feed fetch − margin); a region with more devices takes several alarms.
- Duplicates: the server must mark a change as sent before sending, so a retried alarm cannot re-send (AC-5).
- Races: the alarm and a client request both run the coordinator; one coordinator instance, as today.
- Test host: unit tests use a fake registration service and never ask for permission or register.
- Localization: Ukrainian and Russian plural-free wording; server text in three languages.
- Entitlement: `aps-environment` added (a signing change: owner's Apple Developer portal / provisioning).
- Unverified: HTTP/2 to APNs through Workers `fetch`; alarm CPU limit on Free; APNs JWT reuse window.

## Tasks

## Group 0: Spike (needs the owner's APNs key)
- [ ] T001 Owner creates the APNs key and stores it as a Workers secret himself; agent never sees it. Agent writes a throwaway Worker script and the steps; results (HTTP version, send time, CPU time from `wrangler tail`) are recorded in the spec.

## Group 1: iOS registration (this repo)
- [ ] T002 Test: `REQ-PUSH-001 registers token and current region once opted in` and the region-change test prove AC-1. Files: `RegionalCheckTests/PushRegistrationTests.swift`
- [ ] T003 Implement: `PushRegistrationService`, store, `AppDelegate` callbacks. Files: `RegionalCheck/Push/*`, `RegionalCheck/App/AppDelegate.swift`
- [ ] T004 Test: opt-out and denied-permission tests prove AC-3. Files: `RegionalCheckTests/PushRegistrationTests.swift`
- [ ] T005 Implement: the Details switch, view model, entitlement. Files: `RegionalCheck/Views/DetailsView.swift`, `DetailsViewModel.swift`, `RegionalCheck.entitlements`
- [ ] T006 Test + Implement: exact-body test proves AC-6; String Catalog strings prove AC-7. Files: `RegionalCheckTests/`, `Localizable.xcstrings`

## Group 2: Requirements and public statements
- [ ] T007 Docs: REQ-PUSH-001..007 in `docs/requirements/push.md`; amend `core.md`, REQ-SURF-009 note, privacy policy, release note; `scripts/spec-trace.sh`. Files: `docs/`

## Group 3: Server (drivecheck-api, its own branch and spec 003, its own session)
- [ ] T008 Spec 003 there: contract above, alarm or cron by the spike, change detection, sender, batches, README "Never" and REQ-API-003 amended.

## Review lows
Round 1 and 2, not fixed:
- `pendingDeleteToken` holds one token: a token rotation T1 → T2 with an offline opt-out can leave T1 on the server.
- `observeRegionChanges` re-arms only after `await sync()` returns, so a region committed during a request in flight is seen on the next trigger.
- `switchStringsAreLocalizedEverywhere` copies the catalog reader instead of `Support/StringCatalog.swift`.
- No red log for the push tests (written after the implementation; stated to the reviewer).
- `Rig` leaks UserDefaults suites in tests; `AppContainer.fixture()` builds the push controller with real dependencies.
- `URLSessionPushRegistrationClient` (path, method, DELETE body, status check) has no test; the AppDelegate token callbacks are untested.
- `RegionalCheck/Push/` is missing from AGENTS.md's folder list and `docs/engineering/project-map.md`.
- The race test relies on one `Task.yield()` to queue the opt-out; the "later launch" permission test models the launch with a second controller only in the CarPlay case.
Round 2 repaired in the last commit: permission is read on every sync (a CarPlay-only launch no longer looks revoked), every launch syncs and refreshes a week-old record, bounded loop, privacy policy wording, tracker comment. Round 2 findings 3 (a wiring test through the CarPlay scene provider) is only partly covered: `startPushRegistration` is tested, the provider call is not. There is no third review.
Not run: simulator drive of the Details switch; any real push; the APNs spike (Group 0, needs the owner's key); the server half (Group 3).

## Review lows (open)

## Verification

`ios-verify` (background, 10-minute timeout), `scripts/spec-trace.sh`; the server's `npm run check`;
the spike's tail logs; an end-to-end send to a TestFlight device only after the owner provides the key
and the provisioning change.

## Points to decide

`plan-critic` findings, unchanged, each with my proposed answer:

1. [plan:51, :45, :94] The alarm loop runs only while a device is registered and the server keeps only
   the latest snapshot; after a restart, a gap or a feed outage the comparison baseline may be hours
   old, so an all-clear could be sent for an alert that ended long ago, and no test covers
   alarm → failed/stale → clear or a cold start. Proposed answer: the server keeps the last
   confirmed status per region with its time; an all-clear counts only when the previous confirmed
   alarm was seen at most 10 minutes earlier and the current feed is fresh; after a longer gap or a
   cold start the baseline is reset silently, with no push. Tests added to the server row of the
   table: alarm → stale → clear (no send), cold start (no send), gap of 11 minutes (no send),
   gap of 9 minutes (send). Owner decides the 10 minutes.
   - Decision: accepted
2. [plan:73, :92] The server keeps `env`, `lang`, `updatedAt` besides token and region, wider than AC-6.
   Proposed answer: amend AC-6 to list exactly token, region, env, lang and last-seen time, and the
   privacy policy says so. Owner decides.
   - Decision: accepted
3. [plan:82, RegionSelection.swift:44, :143, core.md:31, privacy-policy.html:20] The region comes from
   location while the app is open; with location denied it is the Kyiv fallback and outside Ukraine it
   stays the last region, so a driver who later drives with the app closed gets all-clears for the
   wrong region. Proposed answer: register only a region that location or the driver's own choice
   set inside Ukraine, never the fallback; the switch caption says "for the last region the app saw".
   Owner decides.
   - Decision: accepted
4. [plan:80, :88-91] Not handled: `didFailToRegisterForRemoteNotificationsWithError`; a PUT or DELETE
   that fails offline (AC-3's "server forgets" depends on the DELETE arriving); permission revoked in
   iOS Settings while the switch reads on (the Live Activity switch handles this,
   `DetailsView.swift:101-110`, REQ-SURF-008). Proposed answer: a pending PUT or DELETE is retried on
   the next foreground; the switch follows the system permission, shows an Open Settings note when it
   is revoked, and sends a DELETE. Tests added to T004. Owner decides.
   - Decision: accepted
5. [plan:51, :73] The 30 s poll interval and the 60-day expiry have no source, and 30 s must be
   checked against the 10 s shared upstream floor (plan:15). Proposed answer: poll every 30 s (above the
   10 s floor, so the alarm never competes with client requests for the upstream slot), drop a token not
   refreshed for 60 days (the app refreshes it on every launch). Owner sets both.
   - Decision: accepted

Owner's answers at this gate (2026-11-09): approach A, falling back to B if the spike shows a 10 ms
alarm limit; gap rule 10 minutes accepted (point 1); AC-6 widened to token, region, env, lang and
last-seen time, and only a location- or user-set region inside Ukraine is registered (points 2, 3);
failure handling, 30 s poll and 60-day expiry accepted (points 4, 5).
