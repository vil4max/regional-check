# Redesign mockups (2026-09-17)

Static 2x exports of the design canvas
(https://claude.ai/artifact/CTqozVQ2Z7x8yEQfFnUigv). The canvas is shared
between sessions and read with the Artifact tool; only drivecheck-designer
publishes to it (`docs/tasks/redesign.md`, section 1). The spec that explains every screen, state, token, and string is
[`docs/tasks/redesign.md`](../../tasks/redesign.md). The CarPlay map options
are explained in
[ADR 0011](../../decisions/0011-carplay-alert-map-candidates.md).

The map picture in the CarPlay mockups is a grey stand-in (the app's
`OutsideUkraineMap` asset), not MapKit and not the Ubilling raster. Regions,
times, and counts are sample data.

Spike screenshots go to `spike/` (see
[`docs/tasks/carplay-map-spike.md`](../../tasks/carplay-map-spike.md)).

## App icon, launch screen, cold start (2026-09-17)

Owner chose icon concept **F · Mark** (`app-icon-mark.png`: current icon vs. Mark; the other concepts were dropped). Production assets and Icon Composer layers: `icon/`. The shipped app icon adds the Status hero's radar sweep, frozen with its bright edge at the top (owner, 2026-09-22); SVG has no conic gradient, so `icon/render-radar-icon.sh` composites it onto the Mark SVGs. Launch and cold-start mockups: `launch-screen.png`, `cold-start-storyboard.png`. Brief: [`docs/tasks/rd-15-app-icon-launch-cold-start.md`](../../tasks/rd-15-app-icon-launch-cold-start.md).

## Onboarding, About, Paywall, Outside Ukraine (2026-09-17, canvas version 26)

DS-3 mockups: `onboarding.png`, `about.png`, `about-pro.png`,
`paywall-plans.png`, `paywall-loading.png`, `paywall-error.png`,
`paywall-empty.png`, `paywall-subscribed.png`, `outside-ukraine.png`. Spec,
owner rulings, and open questions:
[`screens-onboarding-about-paywall.md`](screens-onboarding-about-paywall.md).

## Canvas source snapshot (`source/`)

The canvas is the workshop; `source/` is a read-only snapshot of one canvas
revision (currently version `1789635605-b2a0`), so a fixed version can be
diffed and re-rendered without opening the canvas. Local sessions can still
read the live canvas with the Artifact tool.

- `boards/*.dc.html` and `boards/canvas.json`: every artboard and the canvas
  index as published.
- `exports.json`: board → PNG in this folder.
- `assets/`: images the boards reference, mapped by `assets/blobs.json`.
- `tokens.canvas.json`: tokens as drawn on the canvas. **Not binding**; the
  binding numbers live in the briefs and, after DS-1, in
  `geometry-and-tokens.md`.
- `render.py`: renders boards to the PNGs listed in `exports.json`.

Rules:

1. Only drivecheck-designer writes `source/`, and replaces it whole for each
   canvas revision in the same commit as the matching PNG exports. Never edit
   files in it by hand.
2. Wrapper boards only pass parameters to the base boards `Main`, `CarPlay`,
   `CarPlayMap`, `CarPlayMapImage` and `ColdStart`; change the base board, not
   the wrapper.
3. `render.py` needs Python 3.11+, `beautifulsoup4`, `playwright` with
   Chromium, and `node`. Installing any of them needs the owner's approval.

Revision history: [CHANGELOG.md](CHANGELOG.md).

## Binding geometry and tokens (DS-1, canvas version 1789649986-4733)

[`geometry-and-tokens.md`](geometry-and-tokens.md): colors, standard and Pro
palettes, hero ring, launch mark, cold start, app icon, casing rule. Pro
mockups: `iphone-home-pro-clear.png`, `iphone-home-pro-stale.png`,
`pro-palette-tokens.png`.

## Missing states (DS-2, canvas version 1789651344-540e)

20 exports in `states/`: Checking, Pro off, location denied, region change
notice, Regions search results and empty, full-screen map loaded/loading/
failed, Reduce Transparency, AX5 (Status, Regions, and the DS-3 screens),
Live Activity stale and checking, cold start stale. Rules and copy:
[`states.md`](states.md).
