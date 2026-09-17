# Agent Task — Spike: which CarPlay alert map can Drive Check ship?

Assignee: drivecheck-ios
State: blocked
Requested by: owner (2026-09-17, redesign session). Owner approval (wave 1): "утверждаю" (I approve), owner direct, 2026-09-17, in drivecheck-product, answering "утверждаете роадмап и запуск волны 1?" (do you approve the roadmap and the wave 1 launch?). Delegated by drivecheck-product.
Evidence: result section below; spike code on local `spike/carplay-map` (never landed)
Requirements: `docs/core.md` (P1–P5, Never), `docs/requirements/surfaces-and-pro-gating.md`, `docs/requirements/aerial-alerts-provider.md`, `docs/requirements/refresh-policy.md`
Decision: `docs/decisions/0011-carplay-alert-map-candidates.md` (Proposed)
Parent: `docs/tasks/redesign.md` (task RD-3)
Owned files: `docs/tasks/carplay-map-spike.md` (this file, result section), `docs/design/redesign/spike/` (screenshots), a throwaway spike branch
Out of scope: shipping code to `main`, editing `docs/core.md` or requirements, any change to fetch, refresh, or region logic
Failure conditions: a variant is recommended without a CarPlay Simulator screenshot; image sizes are guessed instead of logged; the spike branch is merged; the recommendation ignores App Review guidance; a Variant B edge case from Q5 is left without an observed or documented answer
Questions for the owner: send them to drivecheck-product as open items; never ask the owner directly (`docs/tasks/redesign.md`, section 1).
Changes a requirement: no (research only). Any recommendation that would change `docs/core.md` or a requirement is written as a proposal for the owner.

## Role and context

You are the agent who will later implement the CarPlay Map tab. Before any
production code, find out which of the two map variants in ADR 0011 can ship
on the iOS 27 SDK and how each one looks in a real CarPlay window. The owner
decides from your report.

Work in your own worktree (`docs/engineering/agent-workflow.md`, Worktree
lifecycle). Spike code stays on a local `spike/carplay-map` branch and is never
sent `READY` for landing.

## Owner direction (2026-09-17)

Update (owner, 2026-09-17): "и переключай карплей на симулятор, не на мой
айфон" (use the simulator for CarPlay, not my iPhone). Measure in the iOS
Simulator CarPlay window only: retry iOS 27 first; if its window stays black,
temporarily set an iOS 26.x deployment target on the never-merged spike branch
and use the 26.5 runtime (card image element only). A simulator-confirmed card
result is enough for RD-9; iOS 27 landscape image items stay open.

The goal is to find out how to show the alert map on CarPlay **safely**. The
service already sends a picture, and the owner prefers showing it
(**Variant B**). Before that is accepted, the spike must read Apple's
documentation and review guidance, and work through the edge cases (Q5), so
that the build is not rejected.

Update (owner, 2026-09-17): "пока не берем это вариант, а работаем с подгрузкой карты картинки + текст" (we do not take that option for now; we work with loading the map as an image plus text). Variant B is the working direction: the
service's map image plus text rows (regions under alert, affected list, image
age), because text cannot be drawn over a CarPlay list image. Variant A is not
pursued; skip Q4. The map is not cut from 3.0.0 in advance: if the spike finds
that Variant B cannot ship safely, report it to drivecheck-product, who takes it
to the owner; do not switch to Variant A on your own.

Builds: at most 2 Xcode builds or test runs machine-wide (`docs/engineering/agent-workflow.md`,
"Build slots"). `just verify`, `just build`, `just test` wait for a slot; run raw
`xcodebuild` as `./scripts/build-slot.sh run xcodebuild …`; for Xcode MCP use
`just build-slot acquire <label>` and `just build-slot release <token>`. Expect
to wait; never stop another session's run; do not raise `BUILD_SLOTS`.

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

### Q4 — Variant A feasibility (not pursued; skip, owner 2026-09-17)

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

### Q5 — Variant B safety and edge cases

Answer each item from the documentation, a simulator run, or both, and say
which:

1. **Review rules.** Quote the CarPlay Developer Guide and App Review
   Guidelines passages that apply to images in list templates for driving
   task apps (content type, text inside images, imagery that needs reading
   while driving). State the concrete rejection risk in one paragraph.
2. **Text in the raster.** The Ubilling picture contains labels and a legend.
   Does that count as text the driver must read? What is the smallest
   rendered label size at the measured image sizes?
3. **Freshness.** How is the image age shown next to the picture? What does
   the tab show when the image is older than the status snapshot, or when the
   status is stale ("No current data") but an older image exists?
4. **Mismatch.** The picture and the JSON snapshot are fetched at different
   times. How does the tab avoid showing a clear map while Status says
   "Air Raid Alert" (or the reverse)?
5. **Failures.** Timeout, no network, HTTP 429 or a ban (2 rps host limit),
   a non-image response, decode failure: what does the row show, and is
   "Refresh map" rate limited?
6. **Appearance.** CarPlay can be dark while the phone is light. Which `?map=`
   variant is requested, and from which trait collection?
7. **Cold launch.** CarPlay connects with the phone app not running: does
   the image load on Map tab appear without blocking Status?
8. **Screen sizes.** Smallest and widest configurations: is Kyiv city
   distinguishable from the oblast? If not, what does the row add?
9. **Accessibility and Siri.** The image label from the snapshot, and what
   CarPlay reads aloud, if anything.
10. **Data cost.** PNG vs WebP size per load on cellular.
11. **API choice.** iOS 27 landscape list image vs the card element
    (`CPListImageRowItemCardElement`, available since iOS 26 and still on
    iOS 27): which renders larger for a driving task app, and which one to
    use.

### Q6 — Cost

Estimate, for each variant: new files, changed files, new tests, new strings,
and new `Info.plist`/entitlement needs.

## Deliverables

- Screenshots in `docs/design/redesign/spike/` named
  `<variant>-<screen-config>.png`.
- A full result report (Q1–Q3, Q5, Q6, recommendation, App Review note draft) sent to drivecheck-product, who fills in the "Agent Result" section below; only drivecheck-product writes documentation.
- Spike code stays on the local `spike/carplay-map` branch and is never sent
  `READY`. The screenshots in `docs/design/redesign/spike/` land on a
  separate docs branch (screenshots only) through `READY` to
  `drivecheck-integrator`; send the
  report to `drivecheck-product`, who brings it to the owner.

## Required final report

# Agent Result

Written by drivecheck-product from drivecheck-ios's report (2026-09-17).

## Outcome

BLOCKED_CORRECTLY for Q2/Q3 measurements; Q1, Q5, Q6, Q15 answered. State set by
drivecheck-product while the owner was away.

## Q1 — Template availability

`CPListTemplate` and `CPInformationTemplate` are documented driving-task tabs;
no driving-task tab count is published (3 tabs fits). Depth: driving-task apps
allow 3 templates on iOS 26.4+ (root included), so tab bar → Map list → one
pushed template fits on the iOS 27 minimum. Card, thumbnail and Details Header
styles have no documented category restriction and no confirmed driving-task
rendering. The owner's iPhone (iOS 27) shows `CPTabBarTemplate` with
Status | Map working.

## Q2 — Measured sizes

| Screen config | CPListItem max | Row element max | Card full-height max | Landscape image | POI visible map |
|---|---|---|---|---|---|
| Standard 800 × 480 (iPhone, CarPlay Simulator.app) | not captured | not captured | not captured | not observed | n/a (Variant A not pursued) |
| Widest | open | open | open | open | n/a |

Window bounds and screen scale read 0 at `didConnect` (scene not laid out yet);
`carTraitCollection` scale 2.0 and style came through. The spike now reads the
environment when the Map tab is selected. Why open: Xcode 27 Device Hub exposes
no CarPlay for simulators (FB24785359 pattern), and the owner asked for
simulator-only checks, not the personal iPhone.

## Q3 — Variant B readability

Open. The live raster is 1000 × 670 PNG (WebP larger) with no text or legend,
which lowers review risk; readability at a measured CarPlay size was not judged.

## Q5 — Variant B safety and edge cases

No passage bans a static image in a list row for driving-task apps. Risks:
App Review guideline "use templates for their intended purpose" and the
driving-task line "custom maps … are not possible" — moderate to low. Light and
dark: read `CPTemplateApplicationScene.contentStyle` and observe
`contentStyleDidChange`. Ubilling: 2 requests per second per host, HTTP 429 and
possible ban on abuse, 3 s cache, informational-only disclaimer, no attribution
terms. Load only on tab appear and Refresh map (no timer, within the 10 s rule).

## Q6 — Cost

About one new builder file (150–200 lines), tab wiring in
`CarPlaySceneDelegate`, new strings (Alert map, Refresh map, count, image age),
tests for rows and the age label. No new entitlements or `Info.plist` keys.

## Recommendation (for the owner to accept or reject)

Do not ship Variant B (RD-9) on this evidence alone: image sizes at more than
one configuration and a readability judgment are missing. Re-run Q2/Q3 when
Device Hub supports CarPlay for simulators, or when the owner allows a short run
on CarPlay Simulator.app. App Review note draft: the CarPlay Map tab shows a
free public alert-status picture (Ubilling Aerial Alerts API), refreshed only
when the tab opens or on Refresh, never on a timer; it is not navigation.

## Related finding

The owner's device showed a 13-minute-old status once while CarPlay was
connected (it recovered later). Cause inconclusive. No test exercises the
periodic refresh loop's ticks during a connection; a board item proposes one.

## Sources

CarPlay Developer Guide (June 2026); WWDC25 "Turbocharge your app for CarPlay";
WWDC26 "Rev up your CarPlay app"; Apple docs for `CPTabBarTemplate`,
`CPListImageRowItemCardElement`, `CPTemplateApplicationScene`; Ubilling Aerial
Alerts API wiki; Apple Developer Forums thread 832565; feedback-assistant
reports issue 842.
