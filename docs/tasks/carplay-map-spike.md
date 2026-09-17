# Agent Task — Spike: which CarPlay alert map can Drive Check ship?

Assignee: unassigned
State: proposed
Requested by: owner (2026-09-17, redesign session)
Evidence: —
Requirements: `docs/core.md` (P1–P5, Never), `docs/requirements/surfaces-and-pro-gating.md`, `docs/requirements/aerial-alerts-provider.md`, `docs/requirements/refresh-policy.md`
Decision: `docs/decisions/0011-carplay-alert-map-candidates.md` (Proposed)
Parent: `docs/tasks/redesign.md` (task RD-3)
Owned files: `docs/tasks/carplay-map-spike.md` (this file, result section), `docs/design/redesign/spike/` (screenshots), a throwaway spike branch
Out of scope: shipping code to `main`, editing `docs/core.md` or requirements, any change to fetch, refresh, or region logic
Failure conditions: a variant is recommended without a CarPlay Simulator screenshot; image sizes are guessed instead of logged; the spike branch is merged; the recommendation ignores App Review guidance

## Role and context

You are the agent who will later implement the CarPlay Map tab. Before any
production code, find out which of the two map variants in ADR 0011 can ship
on the iOS 27 SDK and how each one looks in a real CarPlay window. The owner
decides from your report.

Work in your own worktree (`docs/engineering/agent-workflow.md`, Worktree
lifecycle). Spike code stays on a local `spike/carplay-map` branch and is never
sent `READY` for landing.

## Required reading

1. `AGENTS.md`, `docs/engineering/agent-workflow.md`
2. `docs/core.md`
3. `docs/decisions/0011-carplay-alert-map-candidates.md`
4. `docs/tasks/redesign.md` — sections "CarPlay" and "Open questions"
5. `RegionalCheck/App/CarPlaySceneDelegate.swift`, `CarPlayTemplateBuilder.swift`,
   `CarPlayLoadState.swift`, `CarPlayRefreshCoordinator.swift`
6. `RegionalCheck/Data/MapImageSource.swift`, `RegionalCheck/Views/MapViewModel.swift`
7. Mockups: `docs/design/redesign/carplay-map-a-mapkit-list.png`,
   `carplay-map-a-mapkit-selected.png`, `carplay-map-b-image-landscape.png`,
   `carplay-map-b-image-card.png`, `carplay-details.png`

## External sources to check (cite what you use)

- CarPlay Developer Guide (current PDF):
  https://developer.apple.com/download/files/CarPlay-Developer-Guide.pdf —
  template table, driving task rules, template depth, refresh limits
- WWDC25 "Turbocharge your app for CarPlay":
  https://developer.apple.com/videos/play/wwdc2025/216/ — list image row
  element styles (row, card, condensed, grid, image grid)
- WWDC26 "Rev up your CarPlay app":
  https://developer.apple.com/videos/play/wwdc2026/212/ — portrait/landscape
  list images, Details Header (iOS 27)
- WWDC20 "Accelerate your app with CarPlay":
  https://developer.apple.com/videos/play/wwdc2020/10635/ — point of interest
  template, tab bar template
- Apple docs: `CPPointOfInterestTemplate`, `CPPointOfInterest`,
  `CPTabBarTemplate` (`maximumTabCount`), `CPListImageRowItem`,
  `CPListImageRowItemCardElement`, `CPListItem.maximumImageSize`
- Ubilling Aerial Alerts API wiki:
  https://wiki.ubilling.net.ua/doku.php?id=aerialalertsapi — `?map=` variants
  (`true`, `nightmode`, `rednight`, `webp`), 3 s server cache, 2 rps host limit,
  HTTP 429 and possible ban on abuse, "informational only" disclaimer

## Questions to answer

### Q1 — Template availability (iOS 27 SDK, driving task entitlement)

1. Can `CPPointOfInterestTemplate` be a tab of `CPTabBarTemplate` for a driving
   task app? What is `CPTabBarTemplate.maximumTabCount` in the simulator?
2. Which `CPListImageRowItem` element styles render for a driving task app?
   Do iOS 27 landscape list images render? Is the iOS 27 Details Header
   available to driving task apps, or only to audio/video apps?
3. Does the template depth rule (3 on iOS 26.4+) still allow tab bar → Map →
   POI detail?

### Q2 — Real sizes

Log, for each simulator screen configuration you test (at least the smallest
and the widest):

- `CPListItem.maximumImageSize`
- `CPListImageRowItemElement.maximumImageSize`
- `CPListImageRowItemCardElement.maximumFullHeightImageSize`
- the landscape list image size (iOS 27), if the API exists
- the visible map area of the POI template next to its list panel

### Q3 — Variant B readability

1. Load `MapImageSource.url(for: .night)` once (respect the 2 rps limit; no
   loop). Scale it to each size from Q2 without cropping (upstream render is
   accepted as-is, see `docs/tasks/map-tab.md`).
2. Screenshot each result in the CarPlay Simulator. Can you tell which
   oblasts are red at arm's length (use a 1:1 screenshot on a 13" laptop at
   about 70 cm as a proxy)? Report honestly; the owner makes the call.
3. Check `?map=webp` size versus PNG. CarPlay needs a `UIImage`; confirm the
   decode works.

### Q4 — Variant A feasibility

1. Build a static table of 25 region centroids (one coordinate per
   `AlertRegion`, including `м. Київ`). Source the coordinates from a public
   dataset and cite it; do not invent them.
2. Show pins only for regions under alert, capped at 12. Define and report the
   rule when more than 12 are under alert (suggestion: current region first,
   then nearest by centroid distance, then the rest by name).
3. Confirm the POI template's update limit (once per 60 s) against
   `docs/requirements/refresh-policy.md`: the status timer runs every 30–300 s.
   Describe how updates would be throttled.
4. Read the App Review guidance for driving task apps and POI templates and
   write down the concrete risk in one paragraph. Do not decide it.

### Q5 — Cost

Estimate, for each variant: new files, changed files, new tests, new strings,
and new `Info.plist`/entitlement needs.

## Deliverables

- Screenshots in `docs/design/redesign/spike/` named
  `<variant>-<screen-config>.png`.
- The "Agent Result" section below, filled in.
- `READY` is **not** sent. Tell the owner the report is ready and stop.

## Required final report

# Agent Result

## Outcome

## Q1 — Template availability

## Q2 — Measured sizes

| Screen config | CPListItem max | Row element max | Card full-height max | Landscape image | POI visible map |
|---|---|---|---|---|---|

## Q3 — Variant B readability

## Q4 — Variant A feasibility and review risk

## Q5 — Cost

## Recommendation (for the owner to accept or reject)

## Sources
