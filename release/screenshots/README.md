# English screenshot set for 3.0.0

Captured on 2026-09-19 from the release-closure candidate using
`SCREENSHOT_SIM="DriveCheck Release Closure" just screenshots`.
The simulator name is a local override; select an available dedicated simulator.
All 11 PNGs in `asc/` are 1284 x 2778 portrait captures.

## Proposed storefront order

1. `asc/01-all-clear-kyiv.png` — Status and summary.
2. `asc/02-alert-active-kharkiv.png` — Alert and nearby regions.
3. `asc/06-regions-tab.png` — Region selection.
4. `asc/07-regions-search-results.png` — Search.
5. `asc/09-map-fullscreen.png` — Fullscreen reference map.
6. `asc/05-onboarding-get-started.png` — Product introduction.

These six images passed local visual inspection for their intended screens.
Owner acceptance and App Store Connect upload remain pending.

The remaining files are supporting captures, not part of the proposed upload:
launch artwork, unavailable state, empty search, About and Paywall. Paywall
prices must be checked against App Store Connect before using that capture in
store metadata. Do not upload the entire directory indiscriminately.

## Capture provenance

Status phases use the existing fixed-clock offline fixtures with actual
MainTabView chrome. Regions and map use the live capture graph and may show a
different alert count; these images are screen examples, not one live session.
The map capture uses the provider raster, not the preview grid. The About and
Paywall phases use their real screens. Capture-only composition is DEBUG-gated.

The initial capture without Status tabs and populated Summary was replaced.
The corrected capture was inspected as a contact sheet and at full size for
Status. Device acceptance of the submitted build is a separate release gate.
