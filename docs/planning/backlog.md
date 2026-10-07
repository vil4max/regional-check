# Backlog

Planned and deferred work for Drive Check. Shipped work is in [CHANGELOG.md](../../CHANGELOG.md) and
[docs/operations/releases/](../operations/releases/); how to ship is in
[release-process.md](../operations/release-process.md). Product boundaries in
[core.md](../core.md) stay authoritative over every item below, and a target version does not by
itself schedule implementation.

## Planned feature versions

Each feature update increments MINOR by one and resets PATCH to zero. Fix-only releases increment
PATCH within that minor version (for example, `3.2.0` → `3.2.1`).

| Target version | Scope |
|----------------|-------|
| 3.2.0 | Additional Pro alternate icons and icon selection (PRO-VIS-1) |
| 3.3.0 | Coordinated Pro launch presentation and cold-start transition (PRO-VIS-2) |

### Pro visual identity: icons (3.2.0) and launch (3.3.0)

Make Pro feel richer and visually distinct through a small collection of alternate app icons and
a coordinated Pro launch and cold-start sequence. It extends the single amber Pro alternate icon
and the launch and cold-start sequence of the redesign, keeping the Mark identity.

| Item | Target version | Proposed outcome | Depends on |
|------|----------------|------------------|------------|
| PRO-VIS-1 | 3.2.0 | A few additional Pro alternate icons, and a choice of icon for Pro users | The Pro alternate icon |
| PRO-VIS-2 | 3.3.0 | A matching Pro launch presentation and cold-start transition | The cold-start sequence, PRO-VIS-1 |

Before implementation: compare icon concepts and launch storyboards, then write requirements with
acceptance criteria. Investigate which parts of the Pro presentation belong in the system launch
screen versus the in-app cold-start sequence, including entitlement availability at launch.

Preserve the neutral unknown-status presentation, the fresh-cache fast path, the 400 ms transition
bound (REQ-LAUNCH-002) and Reduce Motion behavior. Pro decoration must not delay or obscure the
free safety signal. The icon count, visual styles, and whether the launch treatment follows the
selected icon remain design decisions.

## Ideas

### Tap a region on the alert map

The whole map is one tap target today and opens the region list. Tapping an individual oblast is
greenfield, not an enhancement of the existing pipeline. The upstream image is a plain raster with
no region semantics (`CarPlayMapBuilder.swift:136-137` records this) and `AlertRegion` carries no
geometry, so it needs either a vector map of the 25 oblasts rendered in-app or a hand-authored
hit-zone overlay pinned to the raster's coordinate space. The latter breaks whenever upstream
changes the image. No target version; the choice between the two needs a design decision first.

### Siri behind the wheel (on hold; value doubtful)

A voice interface for the CarPlay mission, specified but not scheduled until Siri's value is
re-evaluated. Constraints for the whole group: no Spotlight indexing (static catalog, not user
content), no navigation handoff, no paywall on the safety signal, no change to fetch, persist or
scheduling logic.

| Item | Goal (testable) |
|------|-----------------|
| SIRI-1 | `Kyiv` resolves to both city and oblast for Siri disambiguation; EN/UK/RU spellings resolve |
| SIRI-2 | Each completed check or refresh is donated exactly once; failures and renders donate nothing |
| SIRI-3 | Regions rows are annotated for `this region` references on iOS 18.4+, with zero visual change |
| SIRI-4 | A `Refresh status in …` phrase in three locales; both actions are listed in Shortcuts |

## Open

### Architecture (audit 2026-10-07)

| Item | Severity | Goal (testable) |
|------|----------|-----------------|
| ARCH-REGION-OWNER | Medium | Give the current region one Store/Session owner and one persistence path; phone and CarPlay follow it without adapter synchronization or duplicate refreshes. Tests cover changes from both surfaces. |
| ARCH-LA-PREFERENCE-STORE | Medium | Move the Live Activity preference into its own store and split purchase and feature-gate boundaries. Tests preserve the stored choice, entitlement behavior and activity lifecycle while removing unrelated fake methods. |
| ARCH-LOWS | Low | Audit fixes 7–12: move `StatusController` out of Views and separate polling/power observation; compute the shared status accent once; inject Settings actions and Details' source label; align shared protocol placement; move REQ IDs from MARK comments into test names and remove process IDs; align ADR 0015's status-details lifecycle with its view modifier. Verify each independently with focused tests or code-to-document checks. |

## Done

Architecture wave 1 host evidence (2026-10-07): both permission-reader and
content-observation test-and-stub patches were run on `ce0dc72`, producing eight
assertion failures and one pass (the pre-existing preference check). On
`7b84cb1`, `just verify` exited 0 with `verify OK (DoD)`. Isolated reviews
approved the changes with low-priority follow-ups.

| Item | Outcome |
|------|---------|
| ARCH-DOCS | Updated architecture limitations and migration status against the composition root, fixture, feature view models and adapters. Documented the injected location fake, completed and partial migration steps, current read-only region list, AI folder and extension snapshot writers, with links to inspected code. Documentation link checks and the 40/40 requirement trace pass. |
| ARCH-DETAILS-SCENEPHASE | Details forwards a plain `isActive` value; `DetailsViewModel` imports Foundation and Observation and retains the active-only permission-refresh rule. Existing REQ-SURF-008 tests cover both permission directions and inactive/background forwarding. Static checks and the wave 1 host build/test gate passed. |
| ARCH-WIDGET-TOKENS | `DriveCheckColors` in DriveCheckKit owns the nine colors shared by the app theme and widget. Both forward to that source; source-level comparison confirms all RGB values are unchanged, and snapshot tests/baselines are untouched. Static checks and the wave 1 host build/test gate passed; review approved with a documentation follow-up. |
| ARCH-LA-PERMISSION-READER | `LiveActivityController` and Details use the permission source injected by `AppContainer`; fixtures share their fixed fake. Permission updates reconcile through the serial lifecycle pipeline, and observation is cancelled on controller release. Eligibility, fixture-wiring, stream and cancellation tests have the wave 1 assertion-red/green evidence above; static checks and the full host gate passed. Review approved with a test-warning follow-up. ActivityKit delivery after a physical-device Settings round trip remains unverified. |
| ARCH-LA-OBSERVE | `MainTabViewModel` observes status state, refresh failures and region title while mounted, covering changes missed by the existing phase-only view trigger. Tests cover same-phase check time, failed-poll staleness, phase changes, repeated appearance and obsolete callbacks after disappearance/reappearance, with the wave 1 assertion-red/green evidence above. Static checks and the full host gate passed; review approved with a test-double follow-up. Time-only staleness, controller-owned observation and consolidation of other push sites remain follow-ups; duplicate pushes from existing triggers or concurrent phone/CarPlay observation and ActivityKit rendering still need device evidence. |
| LA-PERM-SETTINGS-RETURN | Details re-reads Live Activity permission on scene activation and retains stream observation. Added REQ-SURF-008 regressions for silent changes in both directions, the preserved driver's choice and inactive/background phases that do not read permission. Strict formatting, SwiftLint and the 40/40 static requirement trace pass. The active-phase regression fails on the previous behavior (assertion red with an empty stub) and passes with the fix, and the full gate passes; the Settings round trip and ActivityKit delivery on a physical device remain unverified. |
| LA-PERM-GAP | The permission stream yields a current-state read after iterator creation, then changes; Details and the permission fakes follow that contract. REQ-SURF-008 regressions cover a subscription-time flip with and without replay. ActivityKit's internal registration timing still needs device evidence. |

## Deferred

| Candidate | Why deferred |
|-----------|--------------|
| `system.open` + `TargetContentProvidingIntent` open-region intent | Requires an iOS 27 SDK decision and a deep-link navigation decision (per `architecture.md`, a Coordinator only when navigation becomes first-class) |
| `system.searchInApp` graceful fallback | Depends on the open-region decision above |
| `SyncableEntity` for cross-device Siri conversations | One-line adoption, but needs a device-pair verification setup first |
| iPhone Duo (foldable) support: verify SwiftUI layout across fold angles and every toolbar | Blocked by the simulator environment, not by the app (below) |

### iPhone Duo spike, 2026-09-23

Checked against the SDK headers of Xcode 27.2 beta (27B5019j), not against secondary articles:

- UIKit, iOS 27.1+: `UIHinge` (status closed / partially open / fully open, angle in radians),
  observed through `UIHingeInteraction`; `UIArrangementViewController` with `UIArrangement`,
  `UISplitArrangement` and `UIOverlayArrangement` place child view controllers.
- SwiftUI: `ArrangementViewStyle` with a `.split` style (`SplitArrangementViewStyle`, `axes(_:)`).
- The `iPhone Duo` simulator device type (`iPhone19,4`) needs runtime 27.1 or later. The iOS 27.2
  beta runtime (24B5084k) lists `iPhone19,4` under `unsupportedDeviceTypes`, and Xcode 27.2 beta
  cannot download a 27.1 runtime ("iOS 27.1 is not available for download"). Xcode 27.0's iOS 27.0
  runtime refuses the device type ("Incompatible device"). No simulator run was possible.

Static readiness of the app: iPhone only (`TARGETED_DEVICE_FAMILY` 1), portrait and both
landscape orientations, no `UIScreen.main` sizing and no fixed screen-wide frames; the only
`GeometryReader` uses are the onboarding and outside-Ukraine sheets. Nothing found that pins
the layout to one screen size, which is evidence, not proof.

Next step: install a runtime that supports `iPhone19,4` (Xcode 27.1 beta ships a 27.1 runtime), or
wait for one. Candidate slices after a simulator run: a screenshot pass folded and unfolded
(Status, Details, fullscreen map, sheets); fixes for what it finds; an optional two-pane Status +
Details when unfolded, which needs a requirement proposal.

Static toolbar inventory, 2026-09-24 (`RegionalCheck/Views`, Release build):

| Surface | Bar | Buttons in the bar |
|---|---|---|
| Status tab | `StatusToolbar` in a `safeAreaBar`: centred title only | None (the DEBUG-only traces button is not shipped) |
| Details tab | `StatusToolbar` with the "Details" title | None |
| Region list | System navigation bar, large title "regions.list.title" | System back button only |
| Tab bar | Native `TabView`, two tabs (Status, Details), tinted | The two tabs |
| Map card (failed state) | No bar; an inline "Refresh" text button in the card | Not a toolbar button |
| Onboarding cover, Outside Ukraine sheet | No bar; one full-width button each | Not toolbar buttons |

There is no `ToolbarItem` anywhere, so no button can be pushed into an overflow menu today and the
priority order is short: the tab bar's two tabs, then the region list's back button. That order is
the rule for any button a later change adds to a bar: a new control names its priority and what it
may collapse into before it lands.

What the simulator run must check, folded and unfolded, portrait and both landscapes:

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

Output: screenshots per state under `just artifacts task iphone-duo-toolbars`, then either one fix
per defect (a failing snapshot or UI test first) or a follow-up item here with the evidence.
