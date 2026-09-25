# Backlog

The task backlog for Drive Check. Each item links to a spec contract in `docs/tasks/` that an agent executes verbatim: Objective → Authorization → Research → Invariants → Behavior → Tests → Acceptance → Failure conditions → Final report.

Spec-driven cycle: **backlog item → task spec → bounded implementation → `just verify` → defect-first review → atomic commit → release notes**. No implementation without a spec; no spec without acceptance criteria.

Product boundaries in `docs/core.md` stay authoritative over every item below.

## Epic: Redesign — iPhone, CarPlay tabs, widgets (3.0.0)

Owner request 2026-09-17. Mockups: `docs/design/redesign/`. Epic brief: [tasks/redesign.md](../tasks/redesign.md); owner rulings R1–R8 and Q9–Q13 are recorded there (sections 4.2–4.3). Core and requirement amendments are in sections 4.4 and 4.5, all approved by the owner and applied. Ships as 3.0.0. Per [ADR 0013](../decisions/0013-one-build-pipeline-or-two.md) a `tf-3.0.0-N` tag requests the build and `v3.0.0` marks the submitted commit afterwards; the older plan to move `v3.0.0` is gone (R7). Release preparation is its own block with entry conditions, and the submission itself is done by a release agent with App Store Connect opened for it (owner, 2026-09-18): [operations/redesign-3.0-owner-handoff.md](../operations/redesign-3.0-owner-handoff.md).

The GitHub Project "Drive Check Redesign" that held status, session, batch and owner approval was retired on 2026-09-21 at the owner's request. Status now lives in this file. The item table after the snapshot lists tasks, specs, goals and dependencies; the status of work in progress is in the task briefs (for example `docs/tasks/ia-simplification-3.0.md`) and in the snapshot that follows.

Board snapshot at retirement, 2026-09-21: 39 items were Done; the rest are listed with the status the board last showed. Several items were finished or made obsolete by later commits without the board being updated.

Reconciled 2026-09-24 against the repository: the third column gives each row's evidence. Three rows had no evidence either way in the Git history; they are marked "Not verified" and are not scheduled.

| Board item | Last board status | Reconciled 2026-09-24 |
|------------|-------------------|-----------------------|
| 3.0 TestFlight device pass: refresh, cache, location, tabs and CarPlay | In progress | Done: 3.0.0 shipped (`v3.0.0` on `82c8d0b`) |
| 3.0 release closure: execution checklist | In progress | Done: 3.0.0 shipped |
| Acceptance backbone: REQ-to-test map and baseline inventory | In progress | Done: `just trace` gates `just verify`; 43 of 43 requirements cited by a test (2026-09-24) |
| Bottom bar sits too high on device, and the fade is too short | In progress | Superseded: the custom bar was replaced by the native glass `TabView` (`docs/tasks/device-pass-fixes.md`) |
| RD-15B Launch screen and cold start | In progress | Done: 1493281 |
| RD-17 Release check: regression and TestFlight | In progress | Done: 3.0.0 shipped |
| Replace Status refresh accessory with pull-to-refresh | In progress | Done: 9d2d256 |
| Runtime: add -skipPackagePluginValidation to xcodebuild backend | In progress | Done in the Runtime (`Tooling/scripts/lib.sh`) |
| Test the periodic refresh loop during a CarPlay session | In progress | Not verified; not scheduled. Re-check before acting |
| Unavailable region says Checking… forever | In progress | Not verified; not scheduled. Re-check before acting |
| Unify the grouped-card look across DS-3 and Status | In progress | Not verified; not scheduled. Re-check before acting |
| RD-13 App Store screenshots 3.0.0 (English) | READY | Done: 3.0.0 shipped |
| RD-14 App Store copy, 3.0 release note, tag move | READY | Done: 3.0.0 shipped |
| RD-12 Accessibility pass | Paused | Deferred after 3.0.0 |
| RD-15C Layered Icon Composer icons (Mark, Pro) | Paused | Parked after 3.0.0 (`docs/tasks/rd-15c-layered-icons.md`, `State: blocked`) |

| Item | Spec | Goal (testable) | Depends on |
|------|------|-----------------|------------|
| RD-EPIC | [tasks/redesign.md](../tasks/redesign.md) | Every mockup ships or has an approved deviation; all RD tasks landed with `just verify` | — |
| RD-0 | [tasks/redesign.md](../tasks/redesign.md) §4.4 | Owner approves or rejects each proposed core/requirement amendment | — |
| RD-1 | [tasks/rd-1-ios-27-minimum.md](../tasks/rd-1-ios-27-minimum.md) | All targets and `DriveCheckKit` require iOS 27; CI builds with release Xcode 27 | — |
| RD-2 | [tasks/rd-2-theme-tokens.md](../tasks/rd-2-theme-tokens.md) | Section 5 tokens and glass helpers exist; no screen changes yet | — |
| RD-3 | [tasks/carplay-map-spike.md](../tasks/carplay-map-spike.md) | Report on Variant B (image plus text) safety and edge cases, measured sizes, screenshots; Variant A not pursued ([ADR 0011](../decisions/0011-carplay-alert-map-candidates.md)) | — |
| RD-4 … RD-12 | [tasks/redesign.md](../tasks/redesign.md) §12 | Briefs written after RD-1/RD-2 land and REQ IDs exist for test-bearing work | RD-1, RD-2, RD-0 |
| RD-13 | [tasks/redesign.md](../tasks/redesign.md) §12 | New App Store screenshots of the new design, English only, owner-approved set | RD-5 … RD-12 |
| RD-14 | [tasks/redesign.md](../tasks/redesign.md) §12 | App Store copy, 3.0 release note and changelog for the redesign; version 3.0.0, owner tags after submission (ADR 0013) | RD-13 |
| RD-15A, RD-15B | [tasks/rd-15-app-icon-launch-cold-start.md](../tasks/rd-15-app-icon-launch-cold-start.md) | Mark icon and Pro alternate ship; launch screen shows the neutral mark; cold start turns it into the status within 400 ms of status, skips the sweep with fresh cache, respects Reduce Motion | A: — · B: RD-2, RD-5 |
| RD-15C | [tasks/rd-15c-layered-icons.md](../tasks/rd-15c-layered-icons.md) | Parked after 3.0.0: an `.icon` package replaces the icon asset catalog, so today's Dark and Tinted icons would be re-authored and the Pro alternate rests on undocumented behaviour; one build settles both | RD-15A |
| DS-1 | [tasks/ds-1-geometry-tokens.md](../tasks/ds-1-geometry-tokens.md) | One ring/launch/icon geometry and standard + Pro token tables in the repo; SVGs without C2PA | — |
| DS-2 | [tasks/ds-2-missing-states.md](../tasks/ds-2-missing-states.md) | PNGs for 11 missing states, including the stale cold-start path and accessibility variants of the DS-3 screens | DS-1 |
| DS-3 | [tasks/redesign.md](../tasks/redesign.md) §12 | Onboarding, About, Paywall, Outside Ukraine sheet designed; spec in `docs/design/redesign/screens-onboarding-about-paywall.md` | — |
| RD-R | [tasks/redesign.md](../tasks/redesign.md) §12 | REQ IDs in all requirements; proposed R4 and cold-start requirements | — |
| RD-CI | [tasks/redesign.md](../tasks/redesign.md) §12 | A later push never cancels a release commit's `main` test run | RD-1 |
| RD-16 | [tasks/redesign.md](../tasks/redesign.md) §12 | Onboarding as real first launch, About, Paywall with subscribed state, Outside Ukraine sheet on leaving Ukraine | DS-3, RD-2, RD-5, RD-0 |
| RD-17 | [tasks/redesign.md](../tasks/redesign.md) §12 | Regression checklist and TestFlight round pass before screenshots and tag | RD-1 … RD-16 |

Constraints: iOS 27 minimum; dark only; safety signal and map stay free; no polling for map images; refresh policy unchanged.

## Epic: IA simplification and release repair (3.0.0)

Owner request 2026-09-20, after the `tf-3.0.0-3` device and car pass. The redesign is held
rather than shipped: the app is simplified to two tabs (Status + Details), the alert map moves
inline onto the Status tab, the region list becomes a drill-down from the map, the
follow-location toggle and region search are removed, the Pro surface is hidden, and the
audit's blockers and dead code are cleared. Brief, charter amendments and open questions:
[tasks/ia-simplification-3.0.md](../tasks/ia-simplification-3.0.md). Decisions:
[ADR 0014](../decisions/0014-hide-pro-for-3-0.md),
[ADR 0015](../decisions/0015-two-tab-phone-ia.md), both Accepted on 2026-09-20.

Shipped in 3.0.0: the owner submitted it to App Review on 2026-09-22, and `v3.0.0` marks
`82c8d0b`.

## Planned feature versions

Owner direction 2026-09-19: each feature update increments MINOR by one;
PATCH resets to zero. Fix-only releases increment PATCH within that minor
version (for example, `3.2.0` → `3.2.1`). Version targets do not authorize
implementation or publication.

| Target version | Scope |
|----------------|-------|
| 3.1.0 | The 3.0 follow-ups: Kyiv Oblast turns Kyiv city to Stay Alert, the Live Activity's grey stale clock, and Stay Alert on the Control Center control. Implemented 2026-09-23. Build 2 adds the stale Live Activity and widget fixes ([tasks/stale-live-activity-widget.md](../tasks/stale-live-activity-widget.md)). Fold glass on Home (FG epic) was removed before submission — retired 2026-09-24 ([tasks/fold-glass-retirement.md](../tasks/fold-glass-retirement.md)) |
| 3.2.0 | Additional Pro alternate icons and icon selection (PRO-VIS-1) |
| 3.3.0 | Coordinated Pro launch presentation and cold-start transition (PRO-VIS-2) |

## Idea: Pro visual identity — icons (3.2.0) and launch (3.3.0)

Owner request 2026-09-19. Make Pro feel richer, more beautiful, and visually
distinct through a small collection of alternate app icons and a coordinated
Pro launch and cold-start sequence.

This is a follow-up to [RD-15: Mark icon, alternate Pro icon, launch and
cold-start sequence](../tasks/rd-15-app-icon-launch-cold-start.md), extending
the single amber Pro alternate with more choices while retaining the Mark identity.

| Item | Target version | Spec | Proposed outcome | Depends on |
|------|----------------|------|------------------|------------|
| PRO-VIS-1 | 3.2.0 | brief TBD | Design a few additional Pro alternate icons and let Pro users choose their preferred icon | RD-15A |
| PRO-VIS-2 | 3.3.0 | brief TBD | Design a matching Pro launch presentation and cold-start transition that make opening the app feel polished and cohesive | RD-15B, PRO-VIS-1 |

Target versions assigned; implementation is not yet approved.
Before implementation, compare icon concepts and launch storyboards for owner
selection, then write a task spec with acceptance criteria. Investigate which
parts of the Pro presentation belong in the system launch screen versus the
in-app cold-start sequence, including entitlement availability at launch.

Preserve RD-15's neutral unknown-status presentation, fresh-cache fast path,
400 ms transition bound, and Reduce Motion behavior. Pro decoration must not
delay or obscure the free safety signal. The exact icon count, visual styles,
and whether the launch treatment follows the selected icon remain design decisions.

## Idea: tap a region on the alert map

Deferred from the 3.0.0 IA simplification, owner decision 2026-09-20: the whole map is one tap
target for now, opening the region list.

Tapping an individual oblast is greenfield, not an enhancement of the existing pipeline. The
upstream image is a plain raster with no region semantics (`CarPlayMapBuilder.swift:136-137`
records this) and `AlertRegion` carries no geometry, so it needs either a vector map of the 25
oblasts rendered in-app or a hand-authored hit-zone overlay pinned to the raster's coordinate
space — and the latter breaks whenever upstream changes the image. No target version; needs a
design decision on which of the two before a spec.

## Epic: Fold glass on Home (3.1.0 target)

**Retired 2026-09-24.** The owner decided to remove the effect from 3.1.0 before it shipped
(round brief [tasks/fold-glass-retirement.md](../tasks/fold-glass-retirement.md)); it never
shipped. The rest of this epic stays as history.

Owner request 2026-09-18, the first feature after the redesign. Reference:
[DuoLikeAnimation](https://github.com/elijah-semyonov/DuoLikeAnimation) (public, MIT, SwiftUI
`layerEffect` plus Core Motion). The whole Home screen goes under the effect: the interface stays on
the plane it occupied at zero tilt, and tilting the phone renders it through frosted glass —
reprojected by perspective, blurred and dimmed in proportion to the gap.

**Reference only, not a dependency.** The demo is read for its model and shader math; the effect is
written in our own code. No SPM package, no vendored sources, no CocoaPods (owner, 2026-09-18). MIT
attribution is recorded only if any line is derived rather than reimplemented.

Targets 3.1.0, after 3.0.0 ships: 3.0.0 is already in release preparation, and a Metal-and-motion
effect over Home would invalidate the App Store screenshots and the regression round.

**Why a decorative effect passes the Constitution.** Owner ruling 2026-09-18: "это мой пет проект,
поэтому делаем теперь не только утилиту но и лабораторию по изучению" (this is my pet project, so
from now on we build not only a utility but also a lab for learning). Learning value is an accepted
reason to add code here, next to reducing complexity and improving the driver's experience. The
ruling does not touch the Never list, and it does not loosen P1 Driver attention on CarPlay: lab
work lives on the phone.

| Item | Spec | Goal (testable) | Depends on |
|------|------|-----------------|------------|
| FG-0 | [core](../core.md) "The lab" | `docs/core.md` records the lab purpose, so an experiment no longer reads as a charter violation; owner approves the wording | Done 2026-09-18 |
| FG-1 | 3.1.0 TestFlight device pass | Spike on a real device over the real Home subtree: frame time, battery over 10 minutes, status legibility at maximum tilt, and what the `compositingGroup` flattening does to the map card and the list; report with measurements and screenshots | Closed: not shipped (retired 2026-09-24) |
| FG-2 | [requirements/fold-glass.md](../requirements/fold-glass.md) | Own `foldEffect` in the app: Metal shader, calibrated zero pose, tilt around the screen's Y axis; no dependency added and no change to Home layout | Done 2026-09-23 with SwiftUI's rotation, blur and dim instead of a shader (no Metal Toolchain on this Mac or CI); a shader is a later lab slice |
| FG-3 | [requirements/fold-glass.md](../requirements/fold-glass.md) | Home adopts the effect; Reduce Motion turns it off; the status hero and its text stay readable at every tilt the model allows | Done 2026-09-23 (REQ-FG-001 to 004) |
| FG-4 | [testing strategy](../engineering/testing-strategy.md) | Deterministic tilt for snapshot tests (the simulator serves no motion data); existing Home baselines stay valid with the effect off | Done 2026-09-23 as `-FoldTilt` scenarios: Prefire does not capture the tilt, and the Home baselines still match |
| FG-5 | 3.1.0 release note | App Store screenshots and the release note reflect the effect, or record that it stays invisible in static captures | Closed: not shipped (retired 2026-09-24) |

Approved and implemented for 3.1.0 on 2026-09-23 (owner, in session).

Constraints: phone-only, never a CarPlay surface (P1 Driver attention); no new data and no new
network traffic; the free safety signal stays readable; no third-party dependency.

Owner answers, 2026-09-23:

1. A setting on Details, on by default.
2. No motion data, including Low Power Mode: a flat interface, no manual fallback.
3. "Status text readable at every tilt" is a failure condition: blur and dim are clamped.

## Epic: Ukraine map tab (2.9, superseded by MAP-2)

Third phone-companion tab showing the upstream Ubilling raster alert map (`?map=`, theme-matched variant) loaded on demand via `AsyncImage`. Charter amended 2026-09-15: map picture of the free signal is allowed as a phone-only glanceable surface, never navigation. Owner rulings: upstream render accepted as-is (no Crimea cropping); tab shows the **image fetch time**, never the snapshot `checkedAt`.

| Item | Spec | Goal (testable) | Status |
|------|------|-----------------|--------|
| MAP-1 | [tasks/map-tab.md](../tasks/map-tab.md) | Map tab loads upstream image on appear + manual refresh, zero polling; VoiceOver label generated from snapshot; CarPlay untouched | Shipped 2.9, superseded by MAP-2 |
| MAP-2 | [tasks/map-on-home.md](../tasks/map-on-home.md) | Map moves off its own tab onto a compact card at the top of Home; two tabs remain (Home, Regions); all MAP-1 behavior (no polling, fetch-time stamp, VoiceOver label, free everywhere) preserved | Card shipped in the redesign (`MapCardView`, two tabs left); the full-screen open is RD-6 and has not landed |

Constraints: no polling, no WebView, no new data beyond the shared snapshot, free on all surfaces, phone-only.

## Epic: Test coverage baseline

Coverage analysis (2026-09-16) showed app launch alone covering 33% of `RegionalCheck.app`, `DriveCheckKit` missing from reports, and main-screen previews unusable for snapshots because they wired the live `AppContainer()`.

| Item | Spec | Goal (testable) | Status |
|------|------|-----------------|--------|
| TEST-1 | [tasks/test-coverage-baseline.md](../tasks/test-coverage-baseline.md) | Inert test host; `DriveCheckKit` measured; `AppContainer.fixture` backs previews and scenario tests; main screens snapshotted; coverage-by-layer re-measured against the baseline | Shipped (`AppContainerFixture` in `main`, f4a9908) |

## Epic: Siri behind the wheel (on hold — value doubtful)

Voice interface for the CarPlay mission. Specs are written and stay in backlog, but not scheduled until the map candidate ships and Siri value is re-evaluated.

| Item | Spec | Goal (testable) | Status |
|------|------|-----------------|--------|
| SIRI-1 | [tasks/siri-entity-string-query.md](../tasks/siri-entity-string-query.md) | `Kyiv` resolves to both city and oblast for Siri disambiguation; EN/UK/RU spellings resolve | Specified (on hold) |
| SIRI-2 | [tasks/siri-donate-actions.md](../tasks/siri-donate-actions.md) | Each completed check/refresh is donated exactly once; failures and renders donate nothing | Specified (on hold) |
| SIRI-3 | [tasks/siri-onscreen-reference.md](../tasks/siri-onscreen-reference.md) | Regions rows annotated for `this region` references on iOS 18.4+, zero visual change | Specified (on hold) |
| SIRI-4 | [tasks/siri-refresh-shortcut.md](../tasks/siri-refresh-shortcut.md) | `Refresh status in …` phrase in three locales; both actions listed in Shortcuts | Specified (on hold) |

Constraints for the whole epic: no Spotlight indexing (static catalog, not user content), no navigation handoff, no paywall on the safety signal, no change to fetch/persist/scheduling logic.

## Test infrastructure

| Item | Spec | Goal (testable) | Status |
|------|------|-----------------|--------|
| SNAP-VER | [tasks/snapshot-version-pin.md](../tasks/snapshot-version-pin.md) | Details snapshot baselines stay valid across build and version bumps; the version line in previews is pinned | In progress (plan approved 2026-09-25) |
| FLAKY-LA | [tasks/flaky-live-activity-permission-test.md](../tasks/flaky-live-activity-permission-test.md) | The REQ-SURF-008 Settings-change test waits on events, not on a count of `Task.yield()`, and passes under load | In progress (plan approved 2026-09-25, after SNAP-VER) |

## Deferred (not in 2.9)

| Candidate | Why deferred |
|-----------|--------------|
| `system.open` + `TargetContentProvidingIntent` open-region intent | Requires iOS 27 SDK decision and a deep-link navigation ruling (per `architecture.md` escalation, Coordinator only when navigation becomes first-class) |
| `system.searchInApp` graceful fallback | Depends on the open-region decision above |
| `SyncableEntity` for cross-device Siri conversations | One-line adoption, but needs a device-pair verification setup first |
| iPhone Duo (foldable) support: verify SwiftUI layout across fold angles | Owner request 2026-09-23. Spike 2026-09-23 (below) is blocked by the simulator environment, not by the app. |
| iPhone Duo toolbars: check every toolbar in the simulator and set button priorities | Owner request 2026-09-24. Inventory done statically (below); the run is blocked like the row above: Xcode 27.0's iOS 27.0 runtime refuses the `iPhone Duo` device type ("Incompatible device", checked 2026-09-24). |

### iPhone Duo spike, 2026-09-23

Checked against the SDK headers of Xcode 27.2 beta (27B5019j), not against secondary articles:

- UIKit, iOS 27.1+: `UIHinge` (status closed / partially open / fully open, angle in radians),
  observed through `UIHingeInteraction`; `UIArrangementViewController` with `UIArrangement`,
  `UISplitArrangement` and `UIOverlayArrangement` place child view controllers.
- SwiftUI: `ArrangementViewStyle` with a `.split` style (`SplitArrangementViewStyle`, `axes(_:)`).
- The `iPhone Duo` simulator device type (`iPhone19,4`) needs runtime 27.1 or later. The iOS 27.2
  beta runtime (24B5084k) lists `iPhone19,4` under `unsupportedDeviceTypes`, and Xcode 27.2 beta
  cannot download a 27.1 runtime ("iOS 27.1 is not available for download"). No simulator run
  was possible.

Static readiness of the app: iPhone only (`TARGETED_DEVICE_FAMILY` 1), portrait and both
landscape orientations, no `UIScreen.main` sizing and no fixed screen-wide frames; the only
`GeometryReader` uses are the onboarding and outside-Ukraine sheets. Nothing found that pins
the layout to one screen size, which is evidence, not proof.

Next step, owner decision: install Xcode 27.1 beta for its 27.1 runtime, or wait for a
runtime that supports `iPhone19,4`. Candidate slices after a simulator run: screenshot pass
folded and unfolded (Status, Details, fullscreen map, sheets); fixes for what it finds; an
optional two-pane Status + Details when unfolded, which needs a REQ proposal.

Toolbar slice (owner request 2026-09-24): run it as soon as a runtime that supports
`iPhone19,4` is installed; a fix lands only if the run shows a defect.

Static inventory, 2026-09-24 (`RegionalCheck/Views`, Release build):

| Surface | Bar | Buttons in the bar |
|---|---|---|
| Status tab | `StatusToolbar` in a `safeAreaBar`: centred title only | None (the DEBUG-only traces button is not shipped) |
| Details tab | `StatusToolbar` with the "Details" title | None |
| Region list | System navigation bar, large title "regions.list.title" | System back button only |
| Tab bar | Native `TabView`, two tabs (Status, Details), tinted | The two tabs |
| Map card (failed state) | No bar; an inline "Refresh" text button in the card | Not a toolbar button |
| Onboarding cover, Outside Ukraine sheet | No bar; one full-width button each | Not toolbar buttons |

There is no `ToolbarItem` anywhere, so no button can be pushed into an overflow menu today and
the priority order is short: the tab bar's two tabs, then the region list's back button.
Record that order as the rule for any button a later change adds to a bar (a new control must
name its priority and what it may collapse into before it lands).

What the run must check, folded and unfolded, portrait and both landscapes:

1. The tab bar. If the unfolded width reports a regular horizontal size class, the default
   `TabView` style may move the tabs to the top of the screen. `StatusView` and `DetailsView`
   inset their content for a bottom tab bar (`MainTabView` note on the bottom safe area), so a
   top bar would leave a gap at the bottom and could cover `StatusToolbar`. Capture both.
2. `StatusToolbar`: the title stays centred and single-line, and the scroll edge effect still
   sits behind it at the unfolded width; the status ring's glow is not cut.
3. Region list: large title, back button and the tab bar across a fold change while the list
   is pushed.
4. The hinge: no toolbar text or button straddles it at partially-open angles
   (`UIHinge` states, see the spike above).

Output: screenshots per state under `just artifacts task iphone-duo-toolbars`, then either one
fix per defect (a failing snapshot or UI test first) or a follow-up item here with the
evidence.

## Done

See `CHANGELOG.md` and `docs/operations/releases/` for shipped releases, and `docs/operations/release-process.md` for how to ship.
