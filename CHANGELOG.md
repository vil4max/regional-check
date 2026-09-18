# Changelog

## [3.0] - unreleased

### Features

- Redesigned Status screen: the region's status at a glance, with nearby alerts shown even while your own region is under alert.
- Redesigned Regions tab with search — find a region by its Ukrainian, Russian or English name whatever language the phone is in.
- CarPlay gained an Alert map tab: the regional map as a reference image, the number of regions under alert, the affected list, and Refresh on demand.
- On iPhone the map moved from a card to an "Alert map" row that opens full screen on demand.
- Redesigned widgets and Live Activity.
- Real first-launch onboarding, a redesigned About screen, a redesigned Pro screen, and a clearer sheet when you leave Ukraine.
- New app icon with Dark and Tinted appearances, and a distinct Pro icon.
- Faster, steadier launch: a cached status appears immediately instead of waiting behind a checking animation.

### Bug Fixes

- A stale or failed refresh no longer downgrades an active alert — only a confirmed all-clear does.
- Onboarding now appears on a first launch outside Ukraine, instead of the outside-Ukraine sheet taking its place.
- Shortcuts shows the region and refresh actions in Russian and Ukrainian instead of raw identifiers.
- A region missing from the alert feed now says so, instead of showing "Checking…" indefinitely.

### Requirements

- Minimum iOS raised to 27.

### Breaking Changes

- None.

## [2.7] - 2026-09-14

### Improvements

- Restored standard refresh frequency (60s quiet / 30s alarm) on cellular data in CarPlay.
- Preserved danger and clear alert statuses during transient connection delays instead of prematurely obscuring them with outdated data labels.
- Added a 3-tier freshness model (`fresh`, `aging`, `expired`) with clear time attribution.
- Preserved danger alerts prominently with explicit staleness markers instead of hiding them behind error screens.

## [2.6] - 2026-09-13

### Improvements

- Updated widgets with clearer alert labels and colors consistent with the app.
- Show an explicit outdated-data state when the last update is no longer current.
- Reduced unnecessary widget refreshes when the cached status has not changed.
- Added the updated layout and refresh control to the secondary-region widget.

## [2.5] - 2026-09-10

### Features

- Made CarPlay driver status clearer and more current while driving.

### Bug Fixes

- Improved the visibility of the clear status in CarPlay with a green indicator.
- Corrected alert-region classification so status alerts are interpreted consistently.

### Chores

- Prepared the app and widget for the 2.5 release.
- Expanded coverage for alert validation, shared-state migration, and refresh behavior.

### Breaking Changes

- None.
