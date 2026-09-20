# IA simplification and release repair for 3.0.0

Assignee: Claude (session "Баги и доделки перед релизом")
State: awaiting owner approval of the charter amendments in §3
Requested by: owner, 2026-09-20 — clean out the dead code, fix everything the audit found,
and simplify the app to two tabs before 3.0.0 ships.
Base: f46a564 (`tf-3.0.0-3`).
Owned files: this brief, `docs/core.md`, `docs/requirements/region-model.md`,
`docs/requirements/surfaces-and-pro-gating.md`, `docs/decisions/0014-*`, `docs/decisions/0015-*`,
`docs/README.md` (decision index), `docs/planning/backlog.md` (epic and deferred idea).

This brief carries no status field for execution; it records the contract. Implementation is
blocked on §3.

## 1. Why

The 3.0 redesign landed across ~20 RD tasks and was never accepted on a device. A read-only
audit on 2026-09-20 — four parallel code reviews plus the owner's screenshots from
`tf-3.0.0-3` and from a real car — found:

- four release blockers (an unverified StoreKit purchase finished before it is refused; Pro
  never revoked in the shared store after a lapse; internal App Store Connect troubleshooting
  copy shipped as the paywall's user-facing error; the widget refresh button never Pro-gated);
- a cluster of status defects that all reduce to one root cause, `hasRefreshFailed` being used
  as a substitute for "the data is old" — including an active air-raid alarm rendered amber
  with a clock while the widget beside it stays red;
- layout regressions from `797a4e5`, which replaced the custom bottom bar with native tabs but
  left the bar's geometry driving the fade, the scroll clearance and the region-change notice;
- a CarPlay session that strands `loadState` in `.loading`, and no CarPlay app icon at all;
- dead code: the custom bottom bar, the Pro palette plumbing, `PremiumFeature.proBadge`, and
  tests that still assert the removed bar's contract and therefore pass green about nothing.

Independently the owner judged the app overloaded: too many tabs, a region list and a region
search that duplicate each other, a follow-location toggle, and a Pro tier with nothing in it
that the owner wants to keep selling.

## 2. Owner decisions — 2026-09-20

1. **Hold 3.0.0.** Cleanup, defect fixes and the new IA ship as one version. Screenshots are
   re-captured once at the end. The set attached in App Store Connect predates `797a4e5` and
   shows a bottom bar that no longer exists, so it must be replaced regardless.
2. **Hide the paywall, keep the StoreKit code.** `SubscriptionManager.start()` stays wired —
   it is what finishes renewal transactions. Every currently Pro-gated capability becomes free.
   Pro returns in 3.2.0 as premium colours plus icon selection (PRO-VIS-1).
3. **Location only. Nothing is pinned by hand.** Owner ruling, 2026-09-20: "не надо руками
   ничего пинить, есть локация - ведем по локации, нет - берем киев, и показываем что включите
   локацию для более точного определения места." There is no follow-location toggle and no
   manual pin. With a location the region follows it; without one the region is Kyiv and the
   app says that enabling location gives a more precise region. The region list reached from
   the map is read-only.
   This supersedes the earlier answer "location plus a manual pick from the map" given the same
   day; the later direct instruction wins.
4. **The nearby-alert line stays on the main screen.** One compact line; the rest of the
   summary moves to Details.
4a. **No second region.** Owner ruling, 2026-09-20: "не будет второго региона, выкинуть." The
   "Also watching" row, the secondary-region widget and its configuration intent, the stored
   `shared.secondaryRegion.v1` key and the `SecondaryRegionStore` seam all go. This follows
   from 3: with no manual pinning there was no in-app way to set a second region left anyway.
   Two consequences to accept: a user who has the secondary widget placed will see it become
   unavailable after the update, and the audit defect where configuring that widget silently
   overwrote the app's own region disappears with the feature rather than being fixed.
5. **The whole map is one tap target.** Per-region hit-testing is greenfield — the upstream
   raster has no region semantics and `AlertRegion` has no geometry — so it goes to the backlog.
6. **Restore and Manage Subscription move into Details.** They exist only inside `PaywallView`
   today and would otherwise disappear with it.
7. **Delete the full-screen map.** The map lives on the Status tab only.

### Target information architecture

**Tab 1 — Status:** floating title only; hero ring + status word + region + meta line; one
compact nearby-alert line; the alert map inline under the hero, sized to the raster's own
aspect ratio; tapping the map pushes the region list; pull to refresh.

**Tab 2 — Details:** the full summary (provider rows, country count, 25-segment bar, affected
list) and settings — location access, Live Activity toggle, Restore / Manage Subscription,
data-source link, disclaimer, version.

The region list reached from the map is read-only: it reports every region's status, and
nothing on it changes which region the app follows.

**Removed:** the Regions tab, region search, the follow-location toggle, manual region pinning,
the second region and its widget, the bottom accessory, `RedesignBottomBar`,
`AlertMapFullScreenView`, the paywall sheet and the crown.

## 3. Proposed charter amendments — owner approval required

`docs/core.md:3` records the charter as owner-approved and amended once before, for RD-0.
These amendments are **proposed, not applied**. Nothing in §5 starts until the owner approves
or rejects each one.

| # | `core.md` today | Proposed |
|---|---|---|
| A1 | Principle: "tabbed companion on phone (Status + Regions)" | "tabbed companion on phone (Status + Details)" |
| A2 | Vision: "The phone companion's Home screen shows the alert status first; an 'Alert map' row under it opens the upstream alert map full screen." | "The phone companion's Status tab shows the alert status first, with the upstream alert map inline under it. Tapping the map opens the region list." |
| A3 | Principle: "The Home screen's 'Alert map' row opens the upstream raster alert map full screen on demand (no polling); it adds no new data beyond the shared snapshot" | "The Status tab shows the upstream raster alert map inline, loaded once per session on demand (no polling); it adds no new data beyond the shared snapshot" |
| A4 | Principle: "One current region (auto or manual) · optional Pro second pin" | "One current region, always from location; Kyiv when there is no location" |
| A5 | Language: "Region: one current region — auto (follow location) or manual (pin) — plus optional Pro secondary region." | "Region: one current region, resolved from location; Kyiv when location is unavailable." |
| A6 | "Symbolic Pro (exception)" — the paragraph describing Pro as shipped | Add: "Suspended for 3.0.x. The entitlement, restore and renewal handling remain in the app; no Pro surface is presented and every listed capability is free. Pro returns in 3.2.0 as premium colours and alternate icon selection. See ADR 0014." |
| A7 | Priorities: unchanged | Unchanged. P3 Simplicity is what this whole change serves, and A1–A6 do not touch P1 or P2. |

### Requirement amendments

**`docs/requirements/region-model.md`** — decision 3 removes manual selection entirely, so this
file changes more than the others.
- **REQ-REGION-003 (manual pin stops following) is retired**, not rewritten. There is no pin and
  no toggle, so the requirement has no subject. `RegionSelection.pin` and
  `setFollowsLocation` lose every caller.
- **REQ-REGION-007 (region change notice with Undo)** — Undo restores the previously selected
  region, which is a manual override by another name. With decision 3 it has nothing to undo.
  Proposed: keep the notice, drop Undo. Telling the driver the region switched is P1 driver
  attention and stays; offering to override it contradicts "always follow location". Flagged
  because REQ-REGION-007 is owner-approved text and this is a behaviour removal, not a rewording.
- **REQ-REGION-009 (location denied)** — proposed: "updates stop, the region falls back to Kyiv,
  the Status tab says that enabling location gives a more precise region and offers Open
  Settings, and CarPlay shows short text only." The denial stays on Status rather than moving to
  Details: `core.md` puts P1 driver attention above P3 simplicity, and a silently frozen region
  is exactly the kind of quiet wrongness the Priorities forbid. The current
  `location.access.pick_region` tip is deleted, not reworded — it tells the driver to do
  something the app no longer offers.
- **Storage prose** — "Manual pin sets `follows_location_v1 = false`. Toggle 'Follow location'
  restores GPS-driven updates" and "Manual pin skips the tracker entirely" both describe removed
  behaviour. `shared.region.followsLocation.v1` becomes vestigial: it is kept in the App Group so
  existing installs migrate cleanly, always reads `true`, and is never written.
- REQ-REGION-002's "treats a missing follow-location flag as true" survives and becomes the only
  rule about that key.
- REQ-REGION-001, 004, 005, 006 unchanged — the resolver, fix filtering and hysteresis are now
  the only path to a region, so they matter more, not less.
- REQ-REGION-008 (outside Ukraine) — the rule "keep the last selected region, Kyiv when there is
  none" already matches decision 3's fallback. Only the sheet's "pick one in Regions" CTA goes.

**`docs/requirements/surfaces-and-pro-gating.md`**
- The "Phone Home screen (Alert map row, full-screen map)" row becomes "Phone Status tab
  (inline alert map)".
- The "Phone Regions tab" row becomes "Phone region list (pushed from the Status map,
  read-only)"; its "manual pin" and "Pin secondary region (context menu)" cells are deleted.
- The Home "secondary region line" cell and the secondary-region widget row are deleted
  (decision 4a), and REQ-SURF-004's "secondary region stays stored" clause goes with them.
- New row for the Details tab.
- REQ-SURF-005 — the nearby-alerts line is currently produced inside the AI summary rows
  (`RegionalCheck/AI/StatusDetailsProvider.swift:70-74`), which are moving to Details. Amend so
  the Status tab's obligation is met by a line computed from `NearbyRegionPolicy` independently
  of the AI summary.
- New **REQ-SURF-007 — Pro hidden for 3.x**: given the Pro surface is hidden, when any
  previously Pro-gated feature is used, then it is available to every user; no crown, PRO chip,
  Pro palette, alternate icon or paywall is presented; renewal transactions are still finished
  by `SubscriptionManager.start()`; and Restore and Manage Subscription remain reachable from
  Details.
- REQ-SURF-004 (Pro loss) — marked "suspended while REQ-SURF-007 is in force" rather than
  deleted, because Pro returns.
- Two existing contradictions get settled in passing: this file calls the Live Activity free
  while ADR 0007 and `SubscriptionManager.allows` make it Pro, and it claims widget refresh is
  Pro while `DriveCheckStatusWidgetView` has no entitlement check at all.

**`docs/requirements/refresh-policy.md`** — owner direction, 2026-09-20: "реализовать безопасно
- важно первая подгрузка - дальше лимитировать рефреш и отдавать кеш с учетом документации"
(implement it safely: the first load is what matters, then throttle refresh and serve cache,
following the documentation).

Most of this is already the written contract and is simply not implemented: the 2 rps host limit,
the 30 s → 60 s → 5 min escalation after a 429, and skipping scheduled polls while the window is
open are all in this file today. Those are code defects for slice 4, not amendments.

Two things the file does not yet say and that this direction adds:
- **A minimum interval between any two network fetches, whatever triggered them.** Today only
  *scheduled* polls respect `suppressPollingUntil`; `refresh(isScheduled: false)` ignores it, and
  `HomeView` fires one on every scene activation. Session open, manual pull, region change,
  scene activation and a CarPlay connect can therefore stack with no floor between them. The
  first load of a session stays immediate and unthrottled — that is the one the driver waits
  for — and everything after it coalesces onto the existing snapshot until the floor passes.
- **Serve the cached snapshot inside that window instead of refetching.** Requests currently use
  `.reloadIgnoringLocalCacheData`, so two surfaces refreshing seconds apart both hit the network
  even though the provider caches raw data server-side for 3 seconds. Returning the held
  snapshot inside the floor makes the app's behaviour match what the server would have answered
  anyway.

Exact floor value is a design decision for the slice, bounded below by the provider's 3 s
server cache and above by the 30 s alarm interval that already exists.

New ADRs, both Proposed: [0014](../decisions/0014-hide-pro-for-3-0.md),
[0015](../decisions/0015-two-tab-phone-ia.md).

## 4. Questions answered by the owner, 2026-09-20

**Q1 — returning to automatic after a manual pin.** Closed by decision 3: there is no manual
pin, so nothing has to return from it. The follow-location toggle, `RegionSelection.pin` and
`setFollowsLocation` are all deleted rather than replaced, and REQ-REGION-003 is retired.

**Q2 — where "Also watching" goes.** Closed by decision 4a: dropped, together with the
secondary-region widget, its configuration intent and the stored key.

**Q3 — the widget and Siri copy change.** Approved ("да, делай аккуратно"). Its scope is now
smaller than when it was asked: the dual-tile layout and the secondary widget are being deleted
outright by 4a, so what actually changes for existing installs is the Status widget's source
line becoming visible and the Siri answer becoming the extended one. "Carefully" is read as: the
widget must not change shape or lose information for anyone, and a placed widget must keep
rendering a valid status through the update rather than falling back to a placeholder.

### Still open

**Q4 — the region change notice.** REQ-REGION-007's Undo cannot survive decision 3 (see §3).
Keeping the notice and dropping Undo is proposed there; it needs the owner's nod because it
removes approved behaviour rather than rewording it.

**Correction to an assumption carried into this brief:** `allows(_:)` and `loadIsPro()` are not
the only Pro gates. `subscription.isPro` is read directly at `MainTabView.swift:40,132`,
`HomeViewModel.swift:53,71`, `StatusToolbar.swift:16-96`, `StatusSummaryCard.swift:51-68` and
`RegionsViewModel.swift:115-117`. Forcing `isPro` true would switch **on** the PRO chip, the
Pro palette and — through `SubscriptionManager.apply` → `AlternateIconManager.sync` — the
alternate Pro icon, which is the opposite of hiding Pro. The functional gates return true; the
decorative `isPro` reads are deleted together with the UI they gate; the palette is pinned to
the free set and the icon is synced to `false` once.

## 5. Slice sequence

Owner ruling, 2026-09-20: "сначала багофикс - я проверяю - потом новые фичи." The work splits
into two phases with an owner acceptance gate between them. Phase A changes no structure: the
app keeps its current two tabs and its current screens, so the owner can check the fixes against
what is already on the device without also re-learning the layout. Phase B restructures, and
only then come the backlog features. Nothing in Phase B starts before the owner has accepted
Phase A on a build.

Strictly serial within each phase: the slices touch overlapping Prefire baselines, and a branch
that re-records a baseline it does not own is rejected at integration.

### Phase A — defects, then owner verification

| Slice | Branch | Content |
|---|---|---|
| A0 | `docs/ia-two-tab-charter` | This brief and the two ADRs. Charter amendments in §3 still need approval before Phase B; Phase A does not depend on them. |
| A1 | `chore/remove-dead-redesign-code` | **Done.** `c98a934` deleted `RedesignBottomBar` with the fade and scroll clearance sized from it, its baselines, its `.prefire.yml` entry and the three tests asserting its removed contract; `29052aa` dropped the unread Pro palette plumbing and the stale `CFBundleShortVersionString`. Deferred out of this slice with reasons: `PremiumFeature.proBadge` (its `switch` arm is rewritten by B7 anyway) and the `statusDetailsRevision` chain (a behaviour question for A4, not a deletion). |
| A2 | — | The `RegionsViewModel` conformance move is not needed until something deletes that file, so it moves to Phase B as B1. |
| 3 | `fix/storekit-blockers` | The four StoreKit defects and the two error strings. Before any Pro hiding, so the fixes are reviewable on their own. |
| 4 | `fix/status-freshness` | The `hasRefreshFailed` cluster: seven defects, one root. A failing test citing its REQ ID first for each. **The 429 backoff goes first**: `UbillingProvider.swift:58` never increments `rateLimitAttempt`, so REQ-REFRESH-005's escalation to five minutes is a constant 30 s, and the provider documents 2 rps per host with "і можливо пермабан" for exceeding it. That is the one defect here that risks the data source itself. |
| A3 | `fix/storekit-blockers` | The four StoreKit defects and the two error strings, on the paywall as it stands. |
| A4 | `fix/refresh-safety` | The 429 backoff that never escalates, the fetch floor and cache serving from §3, and the `hasRefreshFailed` cluster: one root, seven symptoms. A failing test citing its REQ ID first for each. |
| A5 | `fix/carplay-loading-and-icon` | The stranded `.loading` paths, the main-actor raster scaling on every render, instrumentation for the two silent render bail-outs, and the missing car-idiom app icon. |
| A6 | `fix/surfaces` | Live Activity adoption of an orphaned activity, the CarPlay client dropped by the Live Activity toggle, the Control Center reload that is never called, widget gallery placeholder, widget token divergence. |
| A7 | `fix/chrome-defects` | Defects fixable without restructuring: the system-blue selected tab, the region-change notice rendering below the tab bar, content scrolling under the unbacked toolbar title, onboarding with no `ScrollView`, the empty SUMMARY card in the Unavailable state. |
| — | **Owner verification gate** | A build the owner checks. Phase B does not start until it is accepted. |

### Phase B — restructure, then backlog features

| Slice | Branch | Content |
|---|---|---|
| B1 | `refactor/service-boundaries` | Relocate the protocol-conformance block out of `RegionsViewModel.swift:5-54` into `RegionalCheck/App/ServiceBoundaries.swift`. Pure move. Must land before anything deletes that file. |
| B2 | `feat/details-tab` | Details as a third tab, so nothing breaks mid-branch. Absorbs `AboutView`, gains Restore / Manage Subscription. Moves the `StatusDetailsViewModel` lifecycle out of `.onAppear` and into `MainTabViewModel`. |
| B3 | `feat/inline-alert-map` | Inline map card extracted from `AlertMapFullScreenView.loadedState`; the cover deleted. The card reserves the raster's aspect ratio from a constant so loading, loaded and failed occupy the same box and the Status tab never reflows when the image lands. Fetch order stays status first, map after the delay; `appear()` keeps its load-once guard. |
| B4 | `feat/region-drilldown` | Two tabs. Read-only region list pushed from the map; search, the follow-location toggle, `RegionSelection.pin` and `setFollowsLocation` deleted; bottom accessory deleted; copy re-pointed in all three locales. |
| B5 | `refactor/drop-secondary-region` | Decision 4a: the "Also watching" row, `DriveCheckSecondaryRegionWidget` and its intent, the Status widget's dual tile, `SecondaryRegionStore`, `shared.secondaryRegion.v1` and every test that covers them. |
| B6 | `feat/status-tab-chrome` | Toolbar reduced to the title; the nearby line as its own helper independent of the AI summary. |
| B7 | `feat/hide-pro` | Last, so nothing else depends on it. |
| B8 | `docs/release-3.0` | Screenshots, changelog, store copy, `just verify`, `just release --check`. |

### Phase C — backlog features

Only after Phase B. Ordered by the backlog's own version targets, not pulled forward:
PRO-VIS-1 (premium colours and icon selection, 3.2.0) is what gives the hidden Pro tier
something to sell again; Fold glass on Home is 3.1.0. Neither is in scope for 3.0.0.

## 5b. Coordination record

Format and reply contract: kit `docs/ai-os/agent-coordination.md`. A subagent has no address of
its own, so it is recorded under its parent session and its reply line is appended here by the
parent, since it cannot message back.

Integrator: session "Баги и доделки перед релизом". Not named by the owner in advance — no other
session was live when landing became necessary; the owner then authorized it directly, first
for three branches ("делай landing всех трёх веток", 2026-09-20) and then as a standing
authorization for every finished Phase A slice ("делай landing и push каждого слайса").

| Slice | Branch | Assignee | State | Requested by | Evidence |
|---|---|---|---|---|---|
| A1 | `chore/remove-dead-redesign-code` | Баги и доделки перед релизом | done | owner (direct, 2026-09-20) | landed, `c9d26c1` |
| A3 | — | — | dropped | owner (direct, 2026-09-20): StoreKit is hidden, not repaired | four paywall-only defects recorded as debt against PRO-VIS-1 |
| A4 | `fix/refresh-safety`, `fix/fetch-floor` | Баги и доделки перед релизом | done | owner (direct, 2026-09-20) | landed, `930c0c9`, `ccc0a90` |
| A5 | `fix/carplay-loading-and-icon` | Баги и доделки перед релизом | done | owner (direct, 2026-09-20) | landed, `5253d4a`; no icon change — the compiled catalog already carries the new single-size icon |
| A6 | `fix/surfaces` | Баги и доделки перед релизом / subagent | claimed | owner (direct, 2026-09-20), delegated by the parent session | — |
| A7 | `fix/chrome-defects` | Баги и доделки перед релизом / subagent | claimed | owner (direct, 2026-09-20), delegated by the parent session | — |

Coordination: A6 and A7 were delegated on 2026-09-20 with the header in the delegation prompt
only and without the contract's "reply DUPLICATE" line; this record was added afterwards. Both
were new tasks with no prior assignee, so neither could have been a duplicate. Files are
disjoint between the two, and only A7 touches Prefire baselines.

## 5a. Standing owner instructions for execution

Owner, 2026-09-20: "всегда запускай симулятор я буду глазами проверять + не забывай карплей".

- **Every slice runs on a live simulator, visible to the owner.** Its own named clone, not the
  shared `iPhone 17`; the build actually under test installed rather than a stale one; the live
  panel attached; and the current screen named in the report. This is the repo rule in
  [agent-workflow.md](../engineering/agent-workflow.md) and it is not optional here — safe-area
  and overlay behaviour are never accepted from a snapshot baseline.
- **CarPlay is checked in every slice that can reach it**, not only slice 10. `core.md` makes
  CarPlay the primary surface and the phone the companion, so a phone-only pass is not
  acceptance. The CarPlay Simulator covers template and layout behaviour; the stuck-loading and
  icon defects need a real head unit.

## 6. Failure conditions

- Any slice starting before §3 is approved.
- `docs/core.md` or a requirement edited without a recorded owner approval.
- A defect fixed without a failing test citing its REQ ID first.
- A branch re-recording a Prefire baseline it does not own.
- Safe-area or overlay behaviour reported as verified from a snapshot baseline rather than a
  running app.
- The nearby-alert line lost from the Status tab at any point in slices 5–8. It is a P1 safety
  signal and it currently lives inside the summary that slice 5 moves away.
- `SubscriptionManager.start()` unwired, which would stop renewal transactions being finished
  for existing subscribers.
