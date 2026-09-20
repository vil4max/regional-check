# ADR 0015 — Two-tab phone IA: Status and Details

Status: Proposed (owner decision pending §3 of
[tasks/ia-simplification-3.0.md](../tasks/ia-simplification-3.0.md))

## Context

The 3.0 redesign shipped the phone companion as Status + Regions. On the TestFlight build the
owner found the result overloaded rather than simplified:

- The Regions tab carries a search field *and* a bottom accessory that is a second button for
  the same search, visible in the same screenshot.
- The Status tab carries a hero, a summary card, a grouped list and — on the Status tab, where
  the accessory has no content — an empty glass capsule above the tab bar.
- The current region, its status and a follow-location toggle appear on the Regions tab,
  duplicating what the Status hero already says.
- The alert map is one row that opens a full-screen cover, so the app's second most useful
  picture is two taps away and the screen that shows it does nothing else.

`docs/core.md` Priorities put P3 Simplicity below P1 driver attention and P2 a free, honest
signal, and the Constitution's utility rule says every line on the driver's path must reduce
complexity or improve the experience. The Regions tab, the search and the toggle fail that test:
none of them is on the driver's path, and the region the driver cares about is already chosen by
location.

## Decision

Two tabs.

**Status** — the floating title, the hero (ring, status word, region, meta line), one compact
nearby-alert line, and the upstream alert map inline directly under the hero. Pull to refresh.
Tapping anywhere on the map pushes the region list.

**Details** — the full summary that was on Status (provider rows, country count, the
25-segment bar, the affected-regions list) and the app's settings, absorbing today's About
screen: location access, the Live Activity toggle, Restore and Manage Subscription, the
data-source link, the disclaimer and the version.

**The region list becomes a read-only drill-down**, pushed from the map inside the Status tab's
navigation stack, reusing `RegionsListModel`. It reports every region's status and changes
nothing: the current region always comes from location, and falls back to Kyiv when there is no
location, with the Status tab saying that enabling location gives a more precise region (owner
ruling, 2026-09-20).

**Removed:** the Regions tab, region search, the follow-location toggle, manual region pinning,
the second region and its widget, the bottom accessory, `RedesignBottomBar`,
`AlertMapFullScreenView`, the paywall sheet and the crown.

### The map is one tap target

Per-region tapping was considered and rejected for this release. The upstream image is a plain
raster with no region semantics — `CarPlayMapBuilder.swift:136-137` already records this — and
`AlertRegion` carries no geometry. Hit-testing would need either a vector map of the 25 oblasts
or a hand-authored overlay, which is a feature in its own right, not an enhancement of the
existing pipeline. It goes to the backlog.

### The inline map, the upstream limit, and the placeholder

Owner direction, 2026-09-20: the map is fetched as a second request, an interval after the
status request — two requests, in that order — and the card carries a placeholder until the
image arrives.

The provider documents the limit as **2 requests per second per host**, and says that exceeding
it returns HTTP 429 "і можливо пермабан" (and possibly a permanent ban). Raw data is cached
server-side for 3 seconds. Two sequential requests separated by `MapViewModel.postStatusDelay`
(1.5 s) are two orders of magnitude below that ceiling, so promoting the map to the Status tab
does not approach the limit — an earlier draft of this ADR overstated the cost. What matters is
not the extra request but never bursting: the status request goes first, the map follows after
the delay, `appear()` keeps its `imageData == nil` guard so a tab switch does not refetch, and
the map stays out of pull-to-refresh. REQ-REFRESH-001's "no polling for map images" is unchanged.

The ban clause raises the priority of a separate defect rather than this one:
`UbillingProvider.swift:58` never increments `rateLimitAttempt`, so REQ-REFRESH-005's escalating
429 backoff is a constant 30 s instead of growing to five minutes. Against a provider that
reserves the right to permaban, retrying every 30 s forever is the behaviour to fix first; it is
slice 4 in the brief.

The placeholder is a layout requirement, not decoration. The card reserves the raster's aspect
ratio from a constant before the image decodes, so the Status tab does not reflow when the map
lands — the current full-screen view has no intrinsic size at all and letterboxes inside an
expanding container, which is the black-banded result in the owner's device screenshot. The
loading and failed states reuse the same reserved box.

The provider also exposes `map=webp` alongside `map=true` and `map=nightmode`, which
`MapImageSource` does not use today. A smaller payload would cut both transfer and the
main-thread decode that CarPlay does on every render; worth evaluating, not decided here.

## Rejected alternatives

- **Keep Regions and just delete the search.** Leaves a whole tab whose top half repeats the
  Status hero and whose purpose — choosing a region — the location already serves.
- **Three tabs: Status, Map, Details.** A tab for one static image, and it puts the map further
  away than the inline card does rather than closer.
- **Region list as a sheet instead of a push.** Re-introduces modal chrome that the rest of
  this change removes, and loses the tab bar and a natural back.
- **Move the nearby-alert line to Details with the rest of the summary.** REQ-SURF-005 is a P1
  safety signal; burying it behind a tab switch trades driver attention for simplicity, which
  the Priorities forbid.
- **Rewrite `AboutView` in place as the Details tab.** Its screen chrome — navigation title,
  "Got It", full-screen-cover dismissal — has no role in a tab; keeping the struct would leave a
  view whose `onDismiss` means nothing.

## Consequences

- `docs/core.md` needs owner-approved amendments: the phone principle becomes "Status +
  Details", and the two places that mandate an "Alert map row [that] opens … full screen" are
  contradicted by the inline card. This ADR proposes them; it does not approve them.
- `docs/requirements/surfaces-and-pro-gating.md` rows for the phone Home screen and the Regions
  tab are rewritten, a Details row is added, and REQ-SURF-005 is amended so the Status tab's
  nearby-alerts obligation is met by a line computed from `NearbyRegionPolicy` rather than by
  the AI summary rows, which move to Details.
- `docs/requirements/region-model.md` loses manual selection altogether: REQ-REGION-003 is
  retired rather than reworded, REQ-REGION-009's "pick a region" tip becomes an invitation to
  enable location, and `shared.region.followsLocation.v1` becomes vestigial — kept for clean
  migration, always read as `true`, never written. REQ-REGION-007's Undo cannot survive either,
  since it restores a previously selected region; keeping the notice without Undo is proposed
  and still needs the owner's nod.
- The resolver, fix filtering and hysteresis (REQ-REGION-004, 005, 006) become the only path to
  a region. They were already correct; they now carry the whole feature, so a regression in them
  has no manual workaround for the driver.
- The second region is dropped entirely (owner ruling, 2026-09-20), taking
  `DriveCheckSecondaryRegionWidget`, its configuration intent, the Status widget's dual tile,
  `SecondaryRegionStore` and `shared.secondaryRegion.v1` with it. A placed secondary widget
  becomes unavailable after the update, and the audit defect where configuring that widget
  overwrote the app's own region disappears with the feature instead of being fixed.
- `RegionsViewModel.swift:5-54` declares protocol conformances that `MapViewModel`,
  `HomeViewModel`, `AppContainer` and `SubscriptionManager` depend on. They move to
  `RegionalCheck/App/ServiceBoundaries.swift` before the view is removed, consistent with
  [ADR 0008](0008-mvvm-service-boundaries.md) placing live dependency composition at the
  application boundary.
- `StatusDetailsView` drives its view model from `.onAppear`. Moving the summary to a second
  tab would stop it refreshing while the driver is on Status, so that lifecycle moves up to
  `MainTabViewModel`, keyed on the snapshot rather than the phase — the phase does not change
  when only neighbouring regions do, which is exactly the case the nearby line reports.
- `docs/engineering/project-map.md` diagrams name the Regions tab and the full-screen map and
  are regenerated with the amendments.
- The App Store screenshot set and `CHANGELOG.md`'s unreleased 3.0 section both describe the
  removed structure and are rewritten before submission.
