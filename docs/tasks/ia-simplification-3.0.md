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
3. **Location first, manual pin as override.** No follow-location toggle. The region list
   reached from the map can still pin a region.
4. **The nearby-alert line stays on the main screen.** One compact line; the rest of the
   summary moves to Details.
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

**Removed:** the Regions tab, region search, the follow-location toggle, the bottom accessory,
`RedesignBottomBar`, `AlertMapFullScreenView`, the paywall sheet and the crown.

## 3. Proposed charter amendments — owner approval required

`docs/core.md:3` records the charter as owner-approved and amended once before, for RD-0.
These amendments are **proposed, not applied**. Nothing in §5 starts until the owner approves
or rejects each one.

| # | `core.md` today | Proposed |
|---|---|---|
| A1 | Principle: "tabbed companion on phone (Status + Regions)" | "tabbed companion on phone (Status + Details)" |
| A2 | Vision: "The phone companion's Home screen shows the alert status first; an 'Alert map' row under it opens the upstream alert map full screen." | "The phone companion's Status tab shows the alert status first, with the upstream alert map inline under it. Tapping the map opens the region list." |
| A3 | Principle: "The Home screen's 'Alert map' row opens the upstream raster alert map full screen on demand (no polling); it adds no new data beyond the shared snapshot" | "The Status tab shows the upstream raster alert map inline, loaded once per session on demand (no polling); it adds no new data beyond the shared snapshot" |
| A4 | Principle: "One current region (auto or manual) · optional Pro second pin" | "One current region, from location by default, manually pinnable from the region list · optional second pin" |
| A5 | Language: "Region: one current region — auto (follow location) or manual (pin) — plus optional Pro secondary region." | Same, minus "Pro": the secondary region is free while Pro is hidden. |
| A6 | "Symbolic Pro (exception)" — the paragraph describing Pro as shipped | Add: "Suspended for 3.0.x. The entitlement, restore and renewal handling remain in the app; no Pro surface is presented and every listed capability is free. Pro returns in 3.2.0 as premium colours and alternate icon selection. See ADR 0014." |
| A7 | Priorities: unchanged | Unchanged. P3 Simplicity is what this whole change serves, and A1–A6 do not touch P1 or P2. |

### Requirement amendments

**`docs/requirements/region-model.md`**
- Storage prose (§ Storage migration) and the hysteresis note: "Toggle 'Follow location' restores
  GPS-driven updates" no longer describes anything. Replace with whatever §4 Q1 decides.
- REQ-REGION-003 — "…until the driver turns it back on" becomes untrue the moment the toggle is
  removed. Its amended form depends on §4 Q1.
- REQ-REGION-007 — Undo after an automatic switch now implies a temporary manual override;
  state that explicitly.
- REQ-REGION-009 — "the Status screen shows the denial with Open Settings and a pick-region tip".
  Proposed: "updates stop, the Status tab shows the denial line, the Details tab carries Open
  Settings and a link to the region list, and CarPlay shows short text only." Flagged because
  `core.md` puts P1 driver attention above P3 simplicity, and a denied location silently freezes
  the region shown on Status — the denial itself must not move off the Status tab.
- REQ-REGION-008 — text unchanged; only the outside-Ukraine sheet's CTA target changes.

**`docs/requirements/surfaces-and-pro-gating.md`**
- The "Phone Home screen (Alert map row, full-screen map)" row becomes "Phone Status tab
  (inline alert map)".
- The "Phone Regions tab" row becomes "Phone region list (pushed from the Status map)".
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

New ADRs, both Proposed: [0014](../decisions/0014-hide-pro-for-3-0.md),
[0015](../decisions/0015-two-tab-phone-ia.md).

## 4. Open questions — owner decision needed before the affected slice

**Q1 — How does a driver get back to automatic after pinning a region manually?**
The follow-location toggle at `RegionalCheck/Views/RegionsView.swift:118-131` is the only UI in
the app that can set `followsLocation` back to `true`. Removing it means one accidental pin
makes the app permanently manual, and REQ-REGION-003's "until the driver turns it back on"
becomes a requirement with no true form.
Recommended: a single non-toggle **"Use my location"** row at the top of the region list,
calling the existing `setFollowsLocation(true, immediateFix:)`. It is not a toggle and not a
settings switch — it is one action, and it is what makes the pin an override rather than a
one-way door. This re-adds an affordance the owner asked to remove, so it needs an explicit call.

**Q2 — Where does "Also watching" go?**
The secondary-region row (`StatusGroupedListCard.swift:52-73`) is unassigned in the new IA. It
is the only in-app consumer of the secondary pin, and the secondary-region widget depends on
the same stored key. Options: move it to Details; keep it on Status under the map; or drop the
feature and the widget with it.

**Q3 — Acknowledge the widget and Siri copy change.**
Making `SharedStore.loadIsPro()` return true frees the widget source line, the dual-tile
"Also watching" layout, the secondary-region widget and the extended Siri answer. That is
consistent with "every Pro feature becomes free", but it changes what already-installed widgets
say for existing users. Confirm that is intended.

**Correction to an assumption carried into this brief:** `allows(_:)` and `loadIsPro()` are not
the only Pro gates. `subscription.isPro` is read directly at `MainTabView.swift:40,132`,
`HomeViewModel.swift:53,71`, `StatusToolbar.swift:16-96`, `StatusSummaryCard.swift:51-68` and
`RegionsViewModel.swift:115-117`. Forcing `isPro` true would switch **on** the PRO chip, the
Pro palette and — through `SubscriptionManager.apply` → `AlternateIconManager.sync` — the
alternate Pro icon, which is the opposite of hiding Pro. The functional gates return true; the
decorative `isPro` reads are deleted together with the UI they gate; the palette is pinned to
the free set and the icon is synced to `false` once.

## 5. Slice sequence

Strictly serial: slices 2–8 all touch overlapping Prefire baselines, and a branch that
re-records a baseline it does not own is rejected at integration.

| Slice | Branch | Content |
|---|---|---|
| 0 | `docs/ia-two-tab-charter` | This brief and the two ADRs. **Blocking on §3 and §4.** |
| 1 | `refactor/service-boundaries` | Relocate the protocol-conformance block out of `RegionsViewModel.swift:5-54` into `RegionalCheck/App/ServiceBoundaries.swift`. Pure move. Must land before anything deletes that file. |
| 2 | `chore/remove-dead-redesign-code` | The custom bottom bar and its baselines, the false-green bar tests, the Pro palette plumbing, `PremiumFeature.proBadge`, the dead `statusDetailsRevision` chain, the unused `CarPlayDependencies.statusDetails`, stale contract comments, the literal `CFBundleShortVersionString = 2.7`. |
| 3 | `fix/storekit-blockers` | The four StoreKit defects and the two error strings. Before any Pro hiding, so the fixes are reviewable on their own. |
| 4 | `fix/status-freshness` | The `hasRefreshFailed` cluster: seven defects, one root. A failing test citing its REQ ID first for each. |
| 5 | `feat/details-tab` | Details as a third tab, so nothing breaks mid-branch. Absorbs `AboutView`. Moves the `StatusDetailsViewModel` lifecycle out of `.onAppear` and into `MainTabViewModel`. |
| 6 | `feat/inline-alert-map` | Inline map card extracted from `AlertMapFullScreenView.loadedState`; the cover deleted. |
| 7 | `feat/region-drilldown` | Two tabs. Region list pushed from the map, search deleted, toggle deleted, bottom accessory and fade deleted, copy re-pointed in all three locales. |
| 8 | `feat/status-tab-chrome` | Toolbar reduced to the title; the nearby line as its own helper; tab tint; region-change notice; onboarding scroll. |
| 9 | `feat/hide-pro` | Last, so nothing else depends on it. |
| 10 | `fix/carplay-loading-and-icon` | The stranded `.loading` paths, the main-actor raster scaling, instrumentation for the silent render bail-outs, and the missing car-idiom icon. |
| 11 | `fix/surfaces` | Widgets, Live Activity adoption, Control Center reload. |
| 12 | `docs/release-3.0` | Screenshots, changelog, store copy, `just verify`, `just release --check`. |

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
