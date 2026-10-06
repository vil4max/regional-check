# Redesign mockups (2026-09-17)

Static 2x exports of the redesign design canvas. The spec that explains every
screen, state, token, and string is split across this folder:
[geometry-and-tokens.md](geometry-and-tokens.md),
[screens-onboarding-about-paywall.md](screens-onboarding-about-paywall.md) and
[states.md](states.md). The shipped CarPlay screen is a single Status screen
(REQ-SURF-006); the earlier CarPlay map mockups are kept as design history.

The map picture in the CarPlay mockups is a grey stand-in (the app's
`OutsideUkraineMap` asset), not MapKit and not the Ubilling raster. Regions,
times, and counts are sample data.

## App icon, launch screen, cold start (2026-09-17)

Icon concept **F · Mark** was chosen (`app-icon-mark.png`: current icon vs. Mark; the other concepts were dropped). Production assets and Icon Composer layers: `icon/`. The shipped app icon is no longer the Mark: it is a road into a sunrise over Kyiv under two red alert-signal arcs (2026-09-22); `icon/road/render-road-icon.sh` turns the source artwork (`icon/road/road-source.png`) into the icon set, with a day sky for Default, a night sky for Dark and a grey foreground on black for Tinted. The Mark, its SVG layers and `icon/render-radar-icon.sh` remain the source of the launch mark and the Status hero. Launch and cold-start mockups: `launch-screen.png`, `cold-start-storyboard.png`. Requirements: [launch-and-cold-start.md](../../requirements/launch-and-cold-start.md).

## Onboarding, About, Paywall, Outside Ukraine (2026-09-17, canvas version 26)

Mockups: `onboarding.png`, `about.png`, `about-pro.png`,
`paywall-plans.png`, `paywall-loading.png`, `paywall-error.png`,
`paywall-empty.png`, `paywall-subscribed.png`, `outside-ukraine.png`. Spec and
decisions: [`screens-onboarding-about-paywall.md`](screens-onboarding-about-paywall.md).

## Canvas source snapshot (`source/`)

`source/` is a read-only snapshot of one canvas revision (currently version
`1789635605-b2a0`), so a fixed version can be diffed and re-rendered without
the canvas itself.

- `boards/*.dc.html` and `boards/canvas.json`: every artboard and the canvas
  index as published.
- `exports.json`: board → PNG in this folder.
- `assets/`: images the boards reference, mapped by `assets/blobs.json`.
- `tokens.canvas.json`: tokens as drawn on the canvas. **Not binding**; the
  binding numbers live in `geometry-and-tokens.md`.
- `render.py`: renders boards to the PNGs listed in `exports.json`.

Rules:

1. `source/` is replaced whole for each canvas revision, in the same commit as
   the matching PNG exports. Never edit files in it by hand.
2. Wrapper boards only pass parameters to the base boards `Main`, `CarPlay`,
   `CarPlayMap`, `CarPlayMapImage` and `ColdStart`; change the base board, not
   the wrapper.
3. `render.py` needs Python 3.11+, `beautifulsoup4`, `playwright` with
   Chromium, and `node`.

Revision history: [CHANGELOG.md](CHANGELOG.md).

## Binding geometry and tokens (canvas version 1789649986-4733)

[`geometry-and-tokens.md`](geometry-and-tokens.md): colors, standard and Pro
palettes, hero ring, launch mark, cold start, app icon, casing rule. Pro
mockups: `iphone-home-pro-clear.png`, `iphone-home-pro-stale.png`,
`pro-palette-tokens.png`.

## Missing states (canvas version 1789651344-540e)

20 exports in `states/`: Checking, Pro off, location denied, region change
notice, Regions search results and empty, full-screen map loaded/loading/
failed, Reduce Transparency, AX5 (Status, Regions, and the onboarding, About
and Paywall screens), Live Activity stale and checking, cold start stale. Rules and copy:
[`states.md`](states.md).
