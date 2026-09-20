# ADR 0011 — CarPlay alert map: two candidates, decided by a spike

Status: Proposed (owner decision pending the spike in
[tasks/carplay-map-spike.md](../tasks/carplay-map-spike.md))

## Release reconciliation — 2026-09-19

Variant B is implemented (`d48b6a6`) and the implementation card is Done.
This does not close the spike's missing multi-configuration measurements and
readability judgment. The recorded owner direction selects image plus text,
but the ADR's conditional acceptance still lacks that evidence. Keep this ADR
Proposed until the release device pass supplies it and the decision is recorded.

## Amendment — 2026-09-20

CarPlay now has two tabs, Status and Map; the Details tab this ADR describes was removed
([tasks/ia-simplification-3.0.md](../tasks/ia-simplification-3.0.md) §4 Q7). The reason the map
is a tab of its own is unchanged: `CPInformationTemplate` cannot show an image. The text below
is kept as the record of the original three-tab decision.

## Context

The redesign ([tasks/redesign.md](../tasks/redesign.md)) turns the CarPlay
surface into three tabs: **Status**, **Map**, **Details**. The owner asked for a
full-screen alert map on the Map tab.

CarPlay does not allow that for Drive Check:

- Drive Check has the `com.apple.developer.carplay-driving-task` entitlement.
  The CarPlay Developer Guide (June 2026) says: "Driving task apps must use the
  provided templates to display information and provide controls. Other kinds
  of CarPlay UI (for example, custom maps, real-time video) are not possible."
- Custom map drawing (`CPMapTemplate` base view) exists only for navigation
  apps. Drive Check is not a navigation app, and `docs/core.md` says it must
  never become one.
- No template shows one image full screen. `CPInformationTemplate` has no
  images at all.

Two templates available to driving task apps can still show a map. Each one
carries a different risk.

| | Variant A — MapKit + pins | Variant B — Ubilling image |
|---|---|---|
| Template | `CPPointOfInterestTemplate` | `CPListTemplate` with `CPListImageRowItem` |
| What the driver sees | Real MapKit map, full template area, pan and zoom, a list panel of up to 12 locations, a detail card with up to 2 buttons on selection | The upstream `?map=` raster (same picture as the phone map card) as a list image |
| Alert signal | One custom pin per region under alert (oblast centroid). Oblasts are not colored | Colored oblasts, exactly as Ubilling renders them |
| Limits | Up to 12 points; POI updates at most once every 60 s | Image size capped by `maximumImageSize` / `CPListImageRowItemCardElement.maximumFullHeightImageSize` and varies by car. Landscape list images are new in iOS 27 and still need a check that driving task apps can use them |
| New data | Needs a static coordinate per region (bundled table); no new network data | None. Reuses `MapImageSource` and the phone map card's fetch policy |
| Main risk | App Review: the guide says driving task apps "are not intended to be location finders" and that POI apps must not be "focused on finding locations on a map" | Readability: 25 oblasts in a card-sized image may be unreadable at a glance |
| Priority fit (`core.md`) | P1 driver attention: pins are easy to read; panning invites interaction | P2 free, honest signal: identical to the phone picture; P3 simplicity: less code |

Mockups: `docs/design/redesign/carplay-map-a-*.png` and
`docs/design/redesign/carplay-map-b-*.png`.

## Decision

Keep both variants until the spike has measured them. The owner picks one
based on:

1. Template availability for driving task apps on the iOS 27 SDK (landscape
   list images, detail header, POI template inside `CPTabBarTemplate`).
2. Real image sizes returned by the CarPlay Simulator for at least the
   smallest and the widest screen configurations, and on one real car if
   available.
3. Whether the Ubilling raster stays readable at that size (owner judgment on
   screenshots).
4. App Review risk for Variant A (a TestFlight external review, or a written
   answer from Apple through the CarPlay entitlement contact, if the owner
   wants one).

If the spike shows that neither variant is available or acceptable, the Map
tab is dropped and CarPlay keeps two tabs (Status, Details).

### Owner direction (2026-09-17)

The owner prefers Variant B, the service's picture, if the spike shows it is
safe for App Review and its edge cases have answers
(`docs/tasks/carplay-map-spike.md`, Q5). This is a preference, not the
decision; the ADR stays Proposed until the owner picks after the spike.

Update (2026-09-17): "пока не берем это вариант, а работаем с подгрузкой карты картинки + текст" (we do not take that option for now; we work with loading the map as an image plus text). Variant B, the image plus text rows, is the
working direction for RD-9; Variant A is not pursued. The ADR becomes Accepted
for Variant B once the spike shows it is safe for App Review; if it is not,
the owner decides again.

## Rejected alternatives

- **Full-screen raster or custom map view.** Not possible for driving task
  apps (see Context).
- **Request the navigation entitlement.** Drive Check is not a navigation app;
  `docs/core.md` forbids turning it into one, and Apple would not grant it.
- **Map image inside the Status tab.** `CPInformationTemplate` cannot show
  images, and the Status tab must stay a one-glance answer (P1).
- **Pick one variant now.** Both depend on facts that only the iOS 27 SDK and
  a CarPlay Simulator run can confirm; guessing risks a rejected build or an
  unreadable map.

## Consequences

- `docs/core.md` needs an owner-approved amendment before either variant ships:
  "One Screen (CarPlay)" becomes "three tabs", and "map card is phone-only"
  no longer holds. This ADR proposes the change; it does not approve it.
- `docs/requirements/surfaces-and-pro-gating.md` gains rows for the CarPlay
  Map and Details tabs. The map stays free (core "Never" list).
- Variant B shares the phone map card's no-polling rule: the image loads when
  the Map tab appears and on "Refresh map", never on a timer.
- Variant A adds a bundled region-to-coordinate table and pin images; it never
  shows a pin for a region whose status is unknown.
