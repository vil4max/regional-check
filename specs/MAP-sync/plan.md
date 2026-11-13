Base: 5d45730ae995c62bc04575d3c27e0d2d603289e3

# Plan: MAP-sync, the inline map follows the status (3.4.0, with LIVEACT-glance)

Spec: `specs/MAP-sync/spec.md`. Skill: `/spec-driven-dev:plan`.

## Context

The owner saw the inline alert map show an older alarm picture than the status above it, after a
pull to refresh and after opening the app from an alert notification (2026-11-12, «Неконсинстентное»).
Research corrected the first diagnosis: the foreground reload exists since 3.2.0
(`MapCardView.swift`, `onChange(of: scenePhase)`, commit `4364c9c`). The real gaps: within one
foreground session nothing reloads a loaded map when the status changes (poll, pull, banner tap);
the pull retries only a failed map by design; and the map request goes through the local HTTP cache
(upstream `max-age=60`, no validators), unlike the status request.

## Business rules

- R1 Polite load: Ubilling allows 2 requests per second per host, 429 over it, "possibly a
  permanent ban"; the map follows the status request by `postStatusDelay` (3 s), never bursting
  (REQ-PROVIDER-002, ADR 0015 lines 72–79).
- R2 A stale picture presented as current is the failure mode to avoid; a failure never shows a
  previous image (ADR 0015; `MapCardView.swift:12-14`).
- R3 A failed map is hidden, no error text or button (UI-simplify AC-4).
- R4 The map loads once per phone foreground session; a tab switch or repeated activation adds no
  request (ADR 0015, amended 2026-10-16).
- R5 No polling for map images (REQ-REFRESH-001 via ADR 0015:79).
- R6 Upstream raster and JSON agreed at 2026-11-12 17:28 UTC. Measured after implementation
  (21:19–21:37 local): upstream alternates between a matching raster and an older east-only one,
  cache-busting does not avoid it, so the spec's assumption is false (spec Assumptions; open point
  below).

## Acceptance criteria and blast radius

AC-1 reload on alarm-set change · AC-2 pull reloads the map · AC-3 no image of another set shown ·
AC-4 bypass the HTTP cache · AC-5 load discipline kept · AC-6 VoiceOver label consistent.

- **May touch:** `RegionalCheck/Views/MapViewModel.swift`, `RegionalCheck/Views/MapCardView.swift`
  (doc comment only), `RegionalCheck/App/AppContainer.swift` (pull wiring, start following),
  `RegionalCheckTests/MapViewModel*Tests.swift`, `RegionalCheckTests/AppScenarioMapTests.swift`,
  `docs/requirements/aerial-alerts-provider.md`, `docs/decisions/0015-two-tab-phone-ia.md`,
  `specs/UI-simplify/spec.md` (amendment note), `CHANGELOG.md`.
- **Must not touch:** `StatusController` polling, `UbillingProvider`, CarPlay, widgets, Live
  Activity, the map raster source or variant logic.
- **Risk class: normal.** No persisted data or public contract; the network load rule (R1) is the
  sensitive part, covered by request-count tests.

## Baseline

Code baseline `6bd22c1`: `ios-verify --base HEAD` PASS, 568 tests (`build/verify/baseline.log`).
HEAD `8e489cd` differs from it only under `specs/` (`git diff --stat 6bd22c1 HEAD -- . ':!specs'`
is empty), so the log stands for this plan too.

## Approach

One approach: keep `MapViewModel` as the only owner of the raster and give it the alarm set its
image was loaded under (`loadedAlarmSet: Set<AlertRegion>?`, read from `statusSource.lastSnapshot`
when the request is sent). It follows `lastSnapshot` with `withObservationTracking`, the pattern
of `LiveActivityPushRegistrar.observeRegion()` (`LiveActivityPushRegistrar.swift:158`), started
once by `AppContainer`. On a change it calls `statusDidChange()`: when the phone session is live
(`!sessionEnded`) and the map is loaded or loading, and the current set differs from the image's
set, it drops the image to the placeholder and starts one load after the status settles and
`postStatusDelay`. A `nil` image set (a map loaded before any snapshot) counts as different from
the first snapshot's set (point 2). The card decides synchronously: `visibleImageData` returns
the image only while `loadedAlarmSet` equals the current snapshot's set, so the old picture never
shows for even one actor turn after the status moves, and the VoiceOver label is computed from the
same set as the shown image (point 4). The pull calls `refreshFromPull(statusWasFetched:)`
(replaces `retryIfFailed()`): `AppContainer.pullToRefresh` passes whether the pull's own status
request returned a new snapshot (`lastSnapshot?.fetchedAt` changed). Fetched: reload a loaded or
failed map, keeping a same-set image until the new one lands. Held by the REQ-REFRESH-010 floor,
failed or rate-limited: only a failed map is retried, as today, so a pull never sends a map request
without a status request before it (point 1). Nothing is sent before the first load. All paths go
through `startLoad(afterStatusSettles: true)`, whose generation counter cancels the older load
during its delay, so a pull that also changes the set sends one request. `startLoad` builds
`URLRequest(url:cachePolicy: .reloadIgnoringLocalCacheData)`.

## Files and types

- `MapViewModel.swift`: `loadedAlarmSet`, `pendingAlarmSet` (the set an in-flight load will carry),
  `statusDidChange()`, `refreshFromPull()` (replaces `retryIfFailed()`), `startFollowingStatus()`,
  cache policy in `startLoad`; doc comments updated to the new triggers.
- `AppContainer.swift`: `pullToRefresh()` calls `refreshFromPull()`; `init` (or
  `startPushRegistration`'s sibling) calls `mapViewModel.startFollowingStatus()` once.
- `MapCardView.swift`: doc comment (lines 3–8) only.
- Alarm set: `AlertRegion.allCases.filter { snapshot.status(for:) == .alarm }`, the same rule as
  `mapAccessibilityLabel` (`RegionalCheck/Data/MapAccessibilityLabel.swift:11`); one helper used
  by both.

## Tests

| AC | Test | Discriminating cases |
|---|---|---|
| AC-1 | `MapViewModelSyncTests`: `REQ-PROVIDER-002 MAP-sync AC-1 a status that changes the alarm set reloads the loaded map once` | {kyivCity} → {kyivCity, kyivOblast}: +1 request, new image; new snapshot, same set (only `checkedAt` moves): +0; map loaded with no snapshot, then the first snapshot: +1; session ended (background) then change: +0; never loaded then change: +0; failed then change: +0; the request comes after the settle wait and `sleep(postStatusDelay)` (recorded order) |
| AC-2 | `REQ-PROVIDER-002 MAP-sync AC-2 a pull reloads the map only after its own status request` | fetched + loaded: +1; fetched + failed: +1; held by the floor + loaded: +0; held + failed: +1 (today's retry); status failed + loaded: +0; before the first load: +0; a pull whose status changes the set: exactly +1, not +2; settle wait and delay recorded before the request |
| AC-3 | `MAP-sync AC-3 the card never shows an image of another alarm set` | snapshot set changes, before any task runs: `visibleImageData == nil` and the label speaks the shown set; same-set pull in flight: old image kept; changed-set reload fails: `loadFailed`, nothing visible |
| AC-4 | `MAP-sync AC-4 the map request bypasses the local cache` | recorded `URLRequest.cachePolicy == .reloadIgnoringLocalCacheData` for appear, pull and status-change loads |
| AC-5 | `MAP-sync AC-5 a status change during a load supersedes it` | change during the delay: one HTTP request; late response of the older generation is not applied; existing session and tab-switch tests stay green |
| AC-1, AC-2 scenario | `AppScenarioMapTests`: `MAP-sync AC-1 a poll that changes the alarm set brings a new map` | real `StatusController` + `FixtureNetwork.alarmRegions` changed, pull: alert +1, map +1; pull again, same set: alert +1, map +1 (AC-2); background → status change: map +0 |
| AC-6 | existing `mapAccessibilityLabel` tests; AC-3 keeps the shown image and the label on one set | — |

## Risks

- Collisions (each needs the owner's word, see Points):
  1. `docs/requirements/aerial-alerts-provider.md:133` REQ-PROVIDER-002 clause 2: "the phone's
     inline alert map (once per session). No surface adds an automatic trigger of its own".
     AC-1 adds an automatic trigger and AC-2 a second map trigger per pull. Approved 2026-09-17,
     amended 2026-09-21/22/23; no decision covers this.
  2. `docs/decisions/0015-two-tab-phone-ia.md:79` "the map stays out of pull-to-refresh".
  3. `specs/UI-simplify/spec.md:33` AC-4 "a loaded map is never re-requested by the pull".
  4. Tests asserting the old rule change with the spec: `AppScenarioMapTests.swift:29`
     (`pullBringsBackAFailedMap`, last block), `MapViewModelSessionTests.swift:73`.
  5. ADR 0015:79 "no polling for map images": the status-change reload rides the shared poll,
     at most one per accepted snapshot (≥ 30 s apart), not a map timer.
- Rate: worst case per 30 s poll in alarm: one status + one map request, 3 s apart; a pull adds the
  same pair. Two orders below 2 rps.
- Lifecycle: a CarPlay-only session polls while the phone is in the background; `sessionEnded`
  and "loaded or loading" guards keep the map silent then (scenario test).
- Observation: `withObservationTracking` fires once per change; re-arm in `onChange` on MainActor;
  the test stub `MapStatusStub` becomes `@Observable` or tests call `statusDidChange()` directly
  and the scenario test proves the wiring with the real `StatusController`.
- Test host: `AlertMapCard` keeps `HostProcess.isUnitTesting`; no live network in tests.
- Upstream lag: if `lag.log` shows the raster later than the JSON by more than 3 s, the spec is
  amended first (a bounded second reload); not built now.

## Tasks

## Group 1: requirements (docs)
- [x] T000 Docs: amend REQ-PROVIDER-002 clause 2 (map triggers: session start, a pull that
  fetched a status, alarm-set change), ADR 0015 amendment 2026-11-12, UI-simplify AC-4 note
  pointing to MAP-sync; record the owner's re-approval of the amended text (plan gate) and refresh
  the fingerprint with `scripts/spec-trace.sh lock --write` so the trace reports no mismatch (point 3).

## Group 2: map follows the status (AC-1, AC-3, AC-4, AC-5)
- [x] T001 Test: AC-1, AC-3, AC-4, AC-5 cases. Files: `RegionalCheckTests/MapViewModelSyncTests.swift`
- [x] T002 Implement: `loadedAlarmSet`, `statusDidChange()`, `startFollowingStatus()`, cache
  policy, shared alarm-set helper. Files: `MapViewModel.swift`, `MapAccessibilityLabel.swift`

## Group 3: the pull reloads the map (AC-2)
- [x] T003 Test: AC-2 cases; update the two old-rule tests (collision 4). Files:
  `MapViewModelSyncTests.swift`, `MapViewModelSessionTests.swift`, `AppScenarioMapTests.swift`
- [x] T004 Implement: `refreshFromPull()`, `AppContainer.pullToRefresh`, start following in
  `AppContainer`. Files: `MapViewModel.swift`, `AppContainer.swift`

## Group 4: proof and notes
- [x] T005 Scenario test with real `StatusController` (table row "scenario"). Files: `AppScenarioMapTests.swift`
- [ ] T006 CHANGELOG 3.4.0 line; doc comments in `MapCardView.swift` and `MapViewModel.swift`;
  manual: simulator run with a fixture alarm change, screenshot before/after in `.artifacts/`.

## Review lows
- `AppContainer.swift:144-147`: a pull that waits for an in-flight scheduled poll counts that poll's
  success as its own status request; load stays one map request per status request (R1 holds),
  only AC-2's wording "own" diverges.
- `MapViewModelTests.swift:205-221` `snapshotChangeRegeneratesLabelWithoutReloading`: an older test
  changes the alarm set and asserts no reload; it passes only because `MapStatusStub` is not
  observable, and now reads against AC-1.
- `red-g2.log`, `red-g3.log` list the failing tests without assertion messages; no red log for the
  scenario wiring (its mutant run instead: without `followStatus()` the scenario fails at 15 s).
- Round 2: `spec.md:37-39` "What happens today" still says the lag "is being measured"; the
  Assumptions section now settles it.
- Round 2: `MapViewModelSyncTests.swift:240` the late-reply check relies on 20 `Task.yield()` turns;
  fewer turns would make it pass vacuously (a false pass, never a false failure).

## Open after implementation
- Upstream serves a stale raster for part of the requests (R6). Owner's decision (2026-11-12): «Карту
  обновляем и экстра логики не пишем, просто должна быть подпись во сколько карта была обновлена»
  → spec AC-7, Group 5.

## Group 5: the map's time caption (AC-7, owner 2026-11-12)
- [x] T007 Test: `MAP-sync AC-7 the map caption gives the load time only under a shown map`
  (`MapViewModel.updatedCaption`: loaded → "Map updated <time>"; loading, failed, other set → nil).
  Files: `RegionalCheckTests/MapViewModelSyncTests.swift`
- [x] T008 Implement: `updatedCaption`, the reserved caption line under the card, the string
  `map.caption.updated` in en/uk/ru; UI-simplify AC-3 note; re-record the map and Status snapshot
  baselines. Files: `MapViewModel.swift`, `MapCardView.swift`, `Localizable.xcstrings`,
  `RegionalCheckSnapshotTests/__Snapshots__/`

## Points to decide

1. Critic: the REQ-REFRESH-010 floor can hold a pull's status request, so a pull would send a map
   request alone. Proposed: the pull reloads the map only when its own status request returned a
   new snapshot; otherwise only a failed map is retried, as today. `fixed in the plan`.
   - Decision: accepted
2. Critic: a map loaded before any snapshot has no set. Proposed: the first snapshot counts as a
   change and reloads it once. `fixed in the plan`.
   - Decision: accepted
3. Critic: amending REQ-PROVIDER-002 changes its lock fingerprint, and the new tests must cite it.
   Proposed: your approval of this plan is the re-approval of the amended clause 2; T000 runs
   `lock --write`; trigger tests are named with REQ-PROVIDER-002. `fixed in the plan`.
   - Decision: accepted
4. Critic: dropping the image one actor turn after the change leaves a window with the old image
   and the new label. Proposed: the card shows the image only while its set equals the current one
   (synchronous), and the label follows the shown set. `fixed in the plan`.
   - Decision: accepted
5. Critic: the tests count requests but not the settle wait and the delay. Proposed: each new
   trigger's test records the order settle → delay → request. `fixed in the plan`.
   - Decision: accepted
6. Spec decision 1: amend REQ-PROVIDER-002 clause 2, ADR 0015 and UI-simplify AC-4 to allow the
   alarm-set trigger and the pull trigger (collisions 1–5). Owner decides.
   - Decision: accepted
7. Spec decision 2: placeholder while a changed-set reload runs (proposed), or the old image with
   a loading mark. Owner decides.
   - Decision: accepted

Owner's answer before approval (2026-11-12): all seven «Принимаю все»; plan approved in the plan
mode dialog the same day.
