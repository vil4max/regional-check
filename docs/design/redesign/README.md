# Redesign mockups (2026-09-17)

Static 2x exports of the design canvas
(https://claude.ai/artifact/CTqozVQ2Z7x8yEQfFnUigv). The canvas is shared
between sessions and read with the Artifact tool; only regional-check-15
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

Owner chose icon concept **F · Mark** (`app-icon-mark.png`: current icon vs. Mark; the other concepts were dropped). Production assets and Icon Composer layers: `icon/`. Launch and cold-start mockups: `launch-screen.png`, `cold-start-storyboard.png`. Brief: [`docs/tasks/rd-15-app-icon-launch-cold-start.md`](../../tasks/rd-15-app-icon-launch-cold-start.md).

## Onboarding, About, Paywall, Outside Ukraine (2026-09-17, canvas version 26)

DS-3 mockups: `onboarding.png`, `about.png`, `about-pro.png`,
`paywall-plans.png`, `paywall-loading.png`, `paywall-error.png`,
`paywall-empty.png`, `paywall-subscribed.png`, `outside-ukraine.png`. Spec,
owner rulings, and open questions:
[`screens-onboarding-about-paywall.md`](screens-onboarding-about-paywall.md).
